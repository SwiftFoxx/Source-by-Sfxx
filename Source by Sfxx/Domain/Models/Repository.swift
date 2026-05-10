import Foundation

struct Repository: Identifiable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var remote: String
    var status: StatusSummary
    var isValid: Bool
}

struct StatusSummary: Hashable {
    var branch: String
    var ahead: Int
    var behind: Int
    var dirtyFiles: Int
}
