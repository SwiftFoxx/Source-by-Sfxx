import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        Form {
            Section("Git Integration") {
                Toggle("Enable Real-Time Monitoring", isOn: .constant(true))
                Toggle("Refresh Status On Launch", isOn: .constant(true))
            }

            Section("Auto Fetch") {
                Toggle("Enable Auto Fetch", isOn: Binding(
                    get: { appModel.autoFetchEnabled },
                    set: { appModel.updateAutoFetchEnabled($0) }
                ))

                Stepper(
                    "Interval: \(appModel.autoFetchIntervalMinutes) min",
                    value: Binding(
                        get: { appModel.autoFetchIntervalMinutes },
                        set: { appModel.updateAutoFetchInterval($0) }
                    ),
                    in: 5...120,
                    step: 5
                )
                .disabled(!appModel.autoFetchEnabled)

                #if os(macOS)
                Picker("Background Fetch", selection: Binding(
                    get: { appModel.backgroundFetchPolicy },
                    set: { appModel.updateBackgroundFetchPolicy($0) }
                )) {
                    ForEach(BackgroundFetchPolicy.supportedPolicies) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                .disabled(!appModel.autoFetchEnabled)
                Text("System scheduled runs when the app is inactive, using macOS background activity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #else
                Text("Background fetch is only available on macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
}
