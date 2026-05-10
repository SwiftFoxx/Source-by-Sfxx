import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case repositories
    case activity
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .repositories: return "Repositories"
        case .activity: return "Activity"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .repositories: return "tray.full"
        case .activity: return "bolt.horizontal"
        case .settings: return "gearshape"
        }
    }
}
