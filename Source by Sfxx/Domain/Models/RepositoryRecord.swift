import Foundation

struct RepositoryRecord: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var remote: String
    var bookmarkData: Data
}
