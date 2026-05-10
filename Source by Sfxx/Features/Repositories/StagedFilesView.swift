import SwiftUI

struct StagedFilesView: View {
    let stagedFiles: [FileChange]
    let unstagedFiles: [FileChange]
    let diff: String
    let selectedDiffTitle: String
    let selectedDiff: String
    let onStage: (FileChange) -> Void
    let onUnstage: (FileChange) -> Void
    let onSelect: (FileChange, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Working Changes")
                .font(.headline)

            SectionHeader(title: "Unstaged")

            if unstagedFiles.isEmpty {
                Text("No unstaged changes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(unstagedFiles) { file in
                    HStack {
                        Text(file.path)
                            .font(.subheadline)
                        Spacer()
                        StatusPill(text: file.status, tint: .orange)
                        Button("Diff") {
                            onSelect(file, false)
                        }
                        .buttonStyle(.bordered)
                        Button("Stage") {
                            onStage(file)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 2)
                }
            }

            SectionHeader(title: "Staged")

            if stagedFiles.isEmpty {
                Text("No staged changes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stagedFiles) { file in
                    HStack {
                        Text(file.path)
                            .font(.subheadline)
                        Spacer()
                        StatusPill(text: file.status, tint: .orange)
                        Button("Diff") {
                            onSelect(file, true)
                        }
                        .buttonStyle(.bordered)
                        Button("Unstage") {
                            onUnstage(file)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 2)
                }
            }

            if !diff.isEmpty {
                Text("Staged Diff")
                    .font(.headline)
                    .padding(.top, 8)

                ScrollView(.horizontal) {
                    Text(diff)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if !selectedDiff.isEmpty {
                Text(selectedDiffTitle.isEmpty ? "File Diff" : selectedDiffTitle)
                    .font(.headline)
                    .padding(.top, 8)

                ScrollView(.horizontal) {
                    Text(selectedDiff)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
