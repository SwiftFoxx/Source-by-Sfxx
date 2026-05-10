import Foundation

struct GitEvent: Hashable {
    let repositoryID: Repository.ID
    let title: String
    let detail: String
    let timestamp: Date
    let kind: ActivityKind
}
