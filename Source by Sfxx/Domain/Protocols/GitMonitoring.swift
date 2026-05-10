import Foundation

protocol GitMonitoring {
    func events(
        for repository: Repository,
        bookmark: Data?,
        access: RepositoryAccess
    ) -> AsyncStream<GitEvent>
}
