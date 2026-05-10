import Foundation

protocol GitClient {
    func status(for repository: Repository) async throws -> StatusSummary
    func branches(for repository: Repository) async throws -> [Branch]
    func log(for repository: Repository, limit: Int) async throws -> [Commit]
    func stagedFiles(for repository: Repository) async throws -> [FileChange]
    func unstagedFiles(for repository: Repository) async throws -> [FileChange]
    func stagedDiff(for repository: Repository) async throws -> String
    func diff(for repository: Repository, path: String, staged: Bool) async throws -> String
    func stageFile(_ repository: Repository, path: String) async throws
    func unstageFile(_ repository: Repository, path: String) async throws
    func fetch(_ repository: Repository) async throws
    func pull(_ repository: Repository) async throws
    func push(_ repository: Repository) async throws
    func commit(_ repository: Repository, message: String, amend: Bool, sign: Bool) async throws
    func checkout(_ repository: Repository, branch: String) async throws
    func createBranch(_ repository: Repository, name: String) async throws
    func deleteBranch(_ repository: Repository, name: String) async throws
    func stash(_ repository: Repository, message: String?) async throws
    func popStash(_ repository: Repository) async throws
    func discardChanges(_ repository: Repository) async throws
}

enum GitClientError: LocalizedError {
    case notImplemented
    case unsupportedPlatform
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "This git action is not implemented yet."
        case .unsupportedPlatform:
            return "This git action is not supported on the current platform."
        case .commandFailed(let message):
            return message
        }
    }
}
