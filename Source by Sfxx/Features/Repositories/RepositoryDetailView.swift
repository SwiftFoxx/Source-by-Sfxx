import SwiftUI

struct RepositoryDetailView: View {
    @Environment(AppModel.self) private var appModel

    let repository: Repository

    @State private var branches: [Branch] = []
    @State private var commits: [Commit] = []
    @State private var stagedFiles: [FileChange] = []
    @State private var unstagedFiles: [FileChange] = []
    @State private var stagedDiff: String = ""
    @State private var selectedDiff: String = ""
    @State private var selectedDiffTitle: String = ""
    @State private var commitMessage: String = ""
    @State private var commitAmend = false
    @State private var commitSign = false
    @State private var loadError: String?
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusRow
                actionGrid
                BranchesListView(
                    branches: branches,
                    onCheckout: checkout,
                    onCreate: createBranch,
                    onDelete: deleteBranch
                )
                StagedFilesView(
                    stagedFiles: stagedFiles,
                    unstagedFiles: unstagedFiles,
                    diff: stagedDiff,
                    selectedDiffTitle: selectedDiffTitle,
                    selectedDiff: selectedDiff,
                    onStage: stage,
                    onUnstage: unstage,
                    onSelect: { file, staged in
                        Task { await selectDiff(file, staged: staged) }
                    }
                )
                CommitComposerView(
                    message: $commitMessage,
                    amend: $commitAmend,
                    sign: $commitSign,
                    onCommit: commit
                )
                CommitListView(commits: commits)
                recentActivity
            }
            .padding(24)
        }
        .navigationTitle(repository.name)
        .toolbar {
            ToolbarItemGroup {
                Button("Refresh") {
                    Task { await appModel.refreshStatus(for: repository) }
                }
                Button("Reload") {
                    Task { await loadRepositoryData() }
                }
            }
        }
        .task {
            await loadRepositoryData()
        }
        .alert("Unable to load repository data", isPresented: $showError) {
            Button("OK") {
                loadError = nil
                showError = false
            }
        } message: {
            Text(loadError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(repository.name)
                .font(.title.bold())
            Text(repository.path)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(repository.remote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            StatusPill(text: repository.status.branch, tint: .blue)
            StatusPill(text: "Ahead \(repository.status.ahead)", tint: .green)
            StatusPill(text: "Behind \(repository.status.behind)", tint: .orange)
            StatusPill(text: "Dirty \(repository.status.dirtyFiles)", tint: .red)
        }
    }

    private var actionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ActionButton(title: "Pull", systemImage: "arrow.down", action: { trigger(.pull) })
                ActionButton(title: "Push", systemImage: "arrow.up", action: { trigger(.push) })
                ActionButton(title: "Fetch", systemImage: "arrow.triangle.2.circlepath", action: { trigger(.fetch) })
                ActionButton(title: "Commit", systemImage: "checkmark.circle", action: { trigger(.commit(message: "")) })
            }
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            if appModel.activity.isEmpty {
                Text("No activity yet. Git events will appear here in real time.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appModel.activity.prefix(5)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func trigger(_ action: GitAction) {
        Task { await appModel.perform(action, on: repository) }
    }

    private func checkout(_ branch: Branch) {
        Task { await appModel.perform(.checkout(branch: branch.name), on: repository) }
    }

    private func stage(_ file: FileChange) {
        Task {
            do {
                try await appModel.stageFile(file.path, in: repository)
                await loadRepositoryData()
            } catch {
                loadError = error.localizedDescription
                showError = true
            }
        }
    }

    private func unstage(_ file: FileChange) {
        Task {
            do {
                try await appModel.unstageFile(file.path, in: repository)
                await loadRepositoryData()
            } catch {
                loadError = error.localizedDescription
                showError = true
            }
        }
    }

    private func commit() {
        Task {
            do {
                try await appModel.commitChanges(
                    message: commitMessage,
                    amend: commitAmend,
                    sign: commitSign,
                    in: repository
                )
                commitMessage = ""
                await loadRepositoryData()
            } catch {
                loadError = error.localizedDescription
                showError = true
            }
        }
    }

    private func createBranch(_ name: String) {
        Task {
            do {
                try await appModel.createBranch(name, in: repository)
                await loadRepositoryData()
            } catch {
                loadError = error.localizedDescription
                showError = true
            }
        }
    }

    private func deleteBranch(_ branch: Branch) {
        Task {
            do {
                try await appModel.deleteBranch(branch.name, in: repository)
                await loadRepositoryData()
            } catch {
                loadError = error.localizedDescription
                showError = true
            }
        }
    }

    private func selectDiff(_ file: FileChange, staged: Bool) async {
        do {
            let diff = try await appModel.loadDiff(for: repository, path: file.path, staged: staged)
            selectedDiff = diff
            selectedDiffTitle = staged ? "Staged Diff • \(file.path)" : "Unstaged Diff • \(file.path)"
        } catch {
            loadError = error.localizedDescription
            showError = true
        }
    }

    private func loadRepositoryData() async {
        do {
            async let loadedBranches = appModel.loadBranches(for: repository)
            async let loadedCommits = appModel.loadCommits(for: repository)
            async let loadedStaged = appModel.loadStagedFiles(for: repository)
            async let loadedUnstaged = appModel.loadUnstagedFiles(for: repository)
            async let loadedDiff = appModel.loadStagedDiff(for: repository)

            branches = try await loadedBranches
            commits = try await loadedCommits
            stagedFiles = try await loadedStaged
            unstagedFiles = try await loadedUnstaged
            stagedDiff = try await loadedDiff
            loadError = nil
            showError = false

            if selectedDiffTitle.isEmpty, let first = stagedFiles.first ?? unstagedFiles.first {
                await selectDiff(first, staged: stagedFiles.contains(first))
            }
        } catch {
            loadError = error.localizedDescription
            showError = true
        }
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RepositoryDetailView(
        repository: Repository(
            id: UUID(),
            name: "Source",
            path: "/Users/you/Projects/Source",
            remote: "git@github.com:sfxx/source.git",
            status: StatusSummary(branch: "main", ahead: 2, behind: 0, dirtyFiles: 3),
            isValid: true
        )
    )
    .environment(AppModel())
}
