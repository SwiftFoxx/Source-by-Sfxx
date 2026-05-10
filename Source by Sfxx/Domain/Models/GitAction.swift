import Foundation

enum GitAction: Hashable {
    case pull
    case push
    case fetch
    case commit(message: String)
    case checkout(branch: String)
    case createBranch(name: String)
    case deleteBranch(name: String)
    case stash(message: String?)
    case popStash
    case discardChanges

    var title: String {
        switch self {
        case .pull: return "Pull"
        case .push: return "Push"
        case .fetch: return "Fetch"
        case .commit: return "Commit"
        case .checkout: return "Checkout"
        case .createBranch: return "Create Branch"
        case .deleteBranch: return "Delete Branch"
        case .stash: return "Stash"
        case .popStash: return "Pop Stash"
        case .discardChanges: return "Discard Changes"
        }
    }
}
