import Foundation

struct GitShellClient: GitClient {
    func status(for repository: Repository) async throws -> StatusSummary {
        #if os(macOS)
        let output = try await runGit(["status", "--porcelain=v1", "-b"], in: repository.path)
        return parseStatus(output)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func branches(for repository: Repository) async throws -> [Branch] {
        #if os(macOS)
        let output = try await runGit(["branch", "--all", "--no-color"], in: repository.path)
        return parseBranches(output)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func log(for repository: Repository, limit: Int) async throws -> [Commit] {
        #if os(macOS)
        let format = "%H%x1f%an%x1f%ad%x1f%s"
        let output = try await runGit([
            "log",
            "--date=iso",
            "--pretty=format:\(format)",
            "-n",
            String(limit)
        ], in: repository.path)
        return parseLog(output)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func stagedFiles(for repository: Repository) async throws -> [FileChange] {
        #if os(macOS)
        let output = try await runGit(["diff", "--cached", "--name-status"], in: repository.path)
        return parseNameStatus(output)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func unstagedFiles(for repository: Repository) async throws -> [FileChange] {
        #if os(macOS)
        let output = try await runGit(["status", "--porcelain=v1"], in: repository.path)
        return parseUnstagedFiles(output)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func stagedDiff(for repository: Repository) async throws -> String {
        #if os(macOS)
        return try await runGit(["diff", "--cached"], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func diff(for repository: Repository, path: String, staged: Bool) async throws -> String {
        #if os(macOS)
        if staged {
            return try await runGit(["diff", "--cached", "--", path], in: repository.path)
        }
        return try await runGit(["diff", "--", path], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func stageFile(_ repository: Repository, path: String) async throws {
        #if os(macOS)
        _ = try await runGit(["add", "--", path], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func unstageFile(_ repository: Repository, path: String) async throws {
        #if os(macOS)
        _ = try await runGit(["reset", "HEAD", "--", path], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func fetch(_ repository: Repository) async throws {
        #if os(macOS)
        _ = try await runGit(["fetch", "--prune"], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func pull(_ repository: Repository) async throws {
        #if os(macOS)
        _ = try await runGit(["pull", "--rebase"], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func push(_ repository: Repository) async throws {
        #if os(macOS)
        _ = try await runGit(["push"], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func commit(_ repository: Repository, message: String, amend: Bool, sign: Bool) async throws {
        #if os(macOS)
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GitClientError.commandFailed("Commit message cannot be empty.")
        }

        var args = ["commit", "-m", trimmed]
        if amend {
            args.append("--amend")
        }
        if sign {
            args.append("-S")
        }

        _ = try await runGit(args, in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func checkout(_ repository: Repository, branch: String) async throws {
        #if os(macOS)
        _ = try await runGit(["checkout", branch], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func createBranch(_ repository: Repository, name: String) async throws {
        #if os(macOS)
        _ = try await runGit(["checkout", "-b", name], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func deleteBranch(_ repository: Repository, name: String) async throws {
        #if os(macOS)
        _ = try await runGit(["branch", "-D", name], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func stash(_ repository: Repository, message: String?) async throws {
        #if os(macOS)
        if let message, !message.isEmpty {
            _ = try await runGit(["stash", "push", "-m", message], in: repository.path)
        } else {
            _ = try await runGit(["stash", "push"], in: repository.path)
        }
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func popStash(_ repository: Repository) async throws {
        #if os(macOS)
        _ = try await runGit(["stash", "pop"], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }

    func discardChanges(_ repository: Repository) async throws {
        #if os(macOS)
        _ = try await runGit(["reset", "--hard"], in: repository.path)
        _ = try await runGit(["clean", "-fd"], in: repository.path)
        #else
        throw GitClientError.unsupportedPlatform
        #endif
    }
}

#if os(macOS)
private extension GitShellClient {
    func runGit(_ arguments: [String], in repositoryPath: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: repositoryPath)

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(decoding: outputData, as: UTF8.self)
                let errorOutput = String(decoding: errorData, as: UTF8.self)

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let message = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    let fallback = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    let combined = message.isEmpty ? (fallback.isEmpty ? "Git command failed." : fallback) : message
                    continuation.resume(throwing: GitClientError.commandFailed(combined))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func parseStatus(_ output: String) -> StatusSummary {
        var branch = "unknown"
        var ahead = 0
        var behind = 0
        var dirtyFiles = 0

        for line in output.split(separator: "\n") {
            if line.hasPrefix("## ") {
                let cleaned = line.replacingOccurrences(of: "## ", with: "")
                let parts = cleaned.split(separator: " ")
                if let namePart = parts.first {
                    let branchParts = namePart.split(separator: "...")
                    branch = String(branchParts.first ?? namePart)
                }
                if cleaned.contains("ahead ") {
                    ahead = extractCount(from: cleaned, key: "ahead")
                }
                if cleaned.contains("behind ") {
                    behind = extractCount(from: cleaned, key: "behind")
                }
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                dirtyFiles += 1
            }
        }

        return StatusSummary(branch: branch, ahead: ahead, behind: behind, dirtyFiles: dirtyFiles)
    }

    func parseBranches(_ output: String) -> [Branch] {
        output.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            let isCurrent = trimmed.hasPrefix("*")
            let cleaned = trimmed.replacingOccurrences(of: "*", with: "")
                .trimmingCharacters(in: .whitespaces)

            let isRemote = cleaned.hasPrefix("remotes/")
            let name = cleaned.replacingOccurrences(of: "remotes/", with: "")

            return Branch(id: UUID(), name: name, isCurrent: isCurrent, isRemote: isRemote)
        }
    }

    func parseLog(_ output: String) -> [Commit] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        let rows = output.split(separator: "\n")
        return rows.compactMap { row in
            let parts = row.split(separator: "\u{1F}")
            guard parts.count == 4 else { return nil }
            let sha = String(parts[0])
            let author = String(parts[1])
            let dateString = String(parts[2])
            let message = String(parts[3])

            let date = formatter.date(from: dateString) ?? Date()

            return Commit(id: sha, message: message, author: author, date: date)
        }
    }

    func parseNameStatus(_ output: String) -> [FileChange] {
        output.split(separator: "\n").map { line in
            let parts = line.split(separator: "\t")
            let status = parts.first.map(String.init) ?? ""
            let path = parts.dropFirst().joined(separator: "\t")
            return FileChange(id: UUID(), path: String(path), status: status)
        }
    }

    func parseUnstagedFiles(_ output: String) -> [FileChange] {
        output.split(separator: "\n").compactMap { line in
            if line.count < 3 { return nil }
            let statusChars = Array(line)
            let index = line.index(line.startIndex, offsetBy: 3)
            let path = line[index...].trimmingCharacters(in: .whitespaces)

            let x = statusChars[0]
            let y = statusChars[1]

            if x == "?" && y == "?" {
                return FileChange(id: UUID(), path: path, status: "??")
            }

            guard y != " " else { return nil }
            return FileChange(id: UUID(), path: path, status: String(y))
        }
    }

    func extractCount(from line: String, key: String) -> Int {
        guard let range = line.range(of: key) else { return 0 }
        let substring = line[range.upperBound...]
        let numbers = substring.filter { $0.isNumber }
        return Int(numbers) ?? 0
    }
}
#endif
