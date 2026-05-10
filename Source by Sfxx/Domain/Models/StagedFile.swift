import Foundation

struct FileChange: Identifiable, Hashable {
    let id: UUID
    let path: String
    let status: String
}
