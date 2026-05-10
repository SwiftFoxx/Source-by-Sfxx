import SwiftUI

struct ActivityView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        List {
            ForEach(appModel.activity) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Activity")
        .overlay {
            if appModel.activity.isEmpty {
                ContentUnavailableView(
                    "No git events yet",
                    systemImage: "bolt.horizontal",
                    description: Text("Connect repositories to see updates in real time.")
                )
            }
        }
    }
}

#Preview {
    ActivityView()
        .environment(AppModel())
}
