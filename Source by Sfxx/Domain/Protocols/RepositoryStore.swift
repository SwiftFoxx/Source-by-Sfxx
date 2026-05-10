import Foundation

protocol RepositoryStore {
    func load() throws -> [RepositoryRecord]
    func save(_ records: [RepositoryRecord]) throws
}
