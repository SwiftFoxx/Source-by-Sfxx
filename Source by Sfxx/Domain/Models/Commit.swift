import Foundation

struct Commit: Identifiable, Hashable {
    let id: String
    var message: String
    var author: String
    var date: Date
}
