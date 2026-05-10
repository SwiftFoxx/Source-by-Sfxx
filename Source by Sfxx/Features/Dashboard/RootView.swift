import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    @State private var selection: SidebarItem = .repositories

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationTitle("Source")
        } detail: {
            switch selection {
            case .repositories:
                RepositoriesView()
            case .activity:
                ActivityView()
            case .settings:
                SettingsView()
            }
        }
        .task {
            appModel.startMonitoring()
        }
        .onDisappear {
            appModel.stopMonitoring()
        }
    }
}

#Preview {
    RootView()
        .environment(AppModel())
}
