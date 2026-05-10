import SwiftUI

struct CommitListView: View {
    let commits: [Commit]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Commits")
                .font(.headline)

            if commits.isEmpty {
                Text("No commits loaded yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(commits) { commit in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(commit.message)
                            .font(.subheadline.weight(.semibold))
                        Text("\(commit.author) • \(commit.date.formatted(date: .numeric, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
