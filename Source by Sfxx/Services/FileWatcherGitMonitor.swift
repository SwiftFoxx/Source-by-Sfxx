import Foundation

#if os(macOS)
import Dispatch
import Darwin
#endif

struct FileWatcherGitMonitor: GitMonitoring {
    func events(
        for repository: Repository,
        bookmark: Data?,
        access: RepositoryAccess
    ) -> AsyncStream<GitEvent> {
        #if os(macOS)
        return AsyncStream { continuation in
            let repoURL: URL
            if let bookmark {
                do {
                    repoURL = try access.resolve(from: bookmark).url
                } catch {
                    continuation.yield(
                        GitEvent(
                            repositoryID: repository.id,
                            title: "Monitoring unavailable",
                            detail: error.localizedDescription,
                            timestamp: Date(),
                            kind: .warning
                        )
                    )
                    continuation.finish()
                    return
                }
            } else {
                repoURL = URL(fileURLWithPath: repository.path)
            }

            let didAccess = repoURL.startAccessingSecurityScopedResource()
            guard let gitURL = Self.resolveGitDirectory(for: repoURL) else {
                if didAccess {
                    repoURL.stopAccessingSecurityScopedResource()
                }
                continuation.yield(
                    GitEvent(
                        repositoryID: repository.id,
                        title: "Monitoring unavailable",
                        detail: "Unable to resolve git metadata for this repository.",
                        timestamp: Date(),
                        kind: .warning
                    )
                )
                continuation.finish()
                return
            }

            guard FileManager.default.fileExists(atPath: gitURL.path) else {
                continuation.yield(
                    GitEvent(
                        repositoryID: repository.id,
                        title: "Monitoring unavailable",
                        detail: "No .git folder found for \(repository.name).",
                        timestamp: Date(),
                        kind: .warning
                    )
                )
                if didAccess {
                    repoURL.stopAccessingSecurityScopedResource()
                }
                continuation.finish()
                return
            }

            let watchTargets = [
                gitURL.appendingPathComponent("HEAD"),
                gitURL.appendingPathComponent("index"),
                gitURL.appendingPathComponent("refs")
            ]

            var sources: [DispatchSourceFileSystemObject] = []
            let queue = DispatchQueue(label: "git.monitor.\(repository.id)")

            for target in watchTargets where FileManager.default.fileExists(atPath: target.path) {
                let fd = open(target.path, O_EVTONLY)
                if fd == -1 { continue }

                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .delete, .rename, .attrib, .extend, .link, .revoke],
                    queue: queue
                )

                source.setEventHandler {
                    let mask = source.data
                    let detail = FileWatcherGitMonitor.describe(eventMask: mask, path: target.lastPathComponent)
                    let event = GitEvent(
                        repositoryID: repository.id,
                        title: "Repository updated",
                        detail: detail,
                        timestamp: Date(),
                        kind: .info
                    )
                    continuation.yield(event)
                }

                source.setCancelHandler {
                    close(fd)
                }

                source.resume()
                sources.append(source)
            }

            if sources.isEmpty {
                continuation.yield(
                    GitEvent(
                        repositoryID: repository.id,
                        title: "Monitoring unavailable",
                        detail: "No watchable git metadata found.",
                        timestamp: Date(),
                        kind: .warning
                    )
                )
                continuation.finish()
                return
            }

            let sourcesSnapshot = sources
            continuation.onTermination = { _ in
                for source in sourcesSnapshot {
                    source.cancel()
                }
                if didAccess {
                    repoURL.stopAccessingSecurityScopedResource()
                }
            }
        }
        #else
        return AsyncStream { continuation in
            continuation.yield(
                GitEvent(
                    repositoryID: repository.id,
                    title: "Monitoring not supported",
                    detail: "File watching is not available on this platform yet.",
                    timestamp: Date(),
                    kind: .info
                )
            )
            continuation.finish()
        }
        #endif
    }

    #if os(macOS)
    private static func resolveGitDirectory(for repoURL: URL) -> URL? {
        let gitPath = repoURL.appendingPathComponent(".git")

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: gitPath.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return gitPath
            }

            if let contents = try? String(contentsOf: gitPath, encoding: .utf8) {
                let prefix = "gitdir:"
                let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.lowercased().hasPrefix(prefix) else { return nil }
                let rawPath = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedURL = URL(fileURLWithPath: rawPath, relativeTo: repoURL).standardizedFileURL
                return resolvedURL
            }
        }

        return nil
    }

    private static func describe(eventMask: DispatchSource.FileSystemEvent, path: String) -> String {
        var reasons: [String] = []
        if eventMask.contains(.write) { reasons.append("write") }
        if eventMask.contains(.delete) { reasons.append("delete") }
        if eventMask.contains(.rename) { reasons.append("rename") }
        if eventMask.contains(.attrib) { reasons.append("metadata") }
        if eventMask.contains(.extend) { reasons.append("extend") }
        if eventMask.contains(.link) { reasons.append("link") }
        if eventMask.contains(.revoke) { reasons.append("revoke") }

        let reasonText = reasons.isEmpty ? "update" : reasons.joined(separator: ", ")
        return "\(path) change detected (\(reasonText))."
    }
    #endif
}
