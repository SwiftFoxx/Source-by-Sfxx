import Foundation

enum BackgroundFetchPolicy: String, CaseIterable, Identifiable, Codable {
    case disabled
    case appActiveOnly
    case systemScheduled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .appActiveOnly:
            return "App Active Only"
        case .systemScheduled:
            return "System Scheduled"
        }
    }

    static var supportedPolicies: [BackgroundFetchPolicy] {
        #if os(macOS)
        return [.disabled, .appActiveOnly, .systemScheduled]
        #else
        return [.disabled, .appActiveOnly]
        #endif
    }
}
