import Foundation

struct ActivityItem: Identifiable, Hashable {
    let id: UUID
    let repositoryID: Repository.ID?
    let title: String
    let detail: String
    let timestamp: Date
    let kind: ActivityKind
}

enum ActivityKind: String, Hashable {
    case info
    case warning
    case error
}
