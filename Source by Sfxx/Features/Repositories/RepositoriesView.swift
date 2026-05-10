import SwiftUI
import UniformTypeIdentifiers

struct RepositoriesView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isImporting = false
    @State private var deleteTarget: Repository?
    @State private var renameTarget: Repository?
    @State private var renameText = ""

    var body: some View {
        @Bindable var appModel = appModel

        NavigationSplitView {
            List(appModel.repositories, selection: $appModel.selectedRepositoryID) { repo in
                VStack(alignment: .leading, spacing: 4) {
                    Text(repo.name)
                        .font(.headline)
                    Text(repo.path.isEmpty ? "Path pending" : repo.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !repo.isValid {
                        Text("Invalid repository")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
                .tag(repo.id)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteTarget = repo
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }

                    Button {
                        renameTarget = repo
                        renameText = repo.name
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .navigationTitle("Repositories")
            .toolbar {
                ToolbarItem {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Add Repository", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let selected = selectedRepository {
                RepositoryDetailView(repository: selected)
            } else {
                EmptyRepositoryStateView()
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                appModel.addRepositories(from: urls)
            case .failure(let error):
                appModel.activity.insert(
                    ActivityItem(
                        id: UUID(),
                        repositoryID: nil,
                        title: "Import failed",
                        detail: error.localizedDescription,
                        timestamp: Date(),
                        kind: .error
                    ),
                    at: 0
                )
            }
        }
        .alert("Remove Repository", isPresented: hasDeleteTarget) {
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
            Button("Remove", role: .destructive) {
                if let repo = deleteTarget {
                    appModel.removeRepository(repo)
                }
                deleteTarget = nil
            }
        } message: {
            Text("This removes the repository from Source. Files are not deleted.")
        }
        .alert("Rename Repository", isPresented: hasRenameTarget) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
            Button("Save") {
                if let repo = renameTarget {
                    appModel.renameRepository(repo, newName: renameText)
                }
                renameTarget = nil
            }
        }
    }

    private var selectedRepository: Repository? {
        guard let id = appModel.selectedRepositoryID else { return nil }
        return appModel.repositories.first(where: { $0.id == id })
    }

    private var hasDeleteTarget: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    private var hasRenameTarget: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }
}

private struct EmptyRepositoryStateView: View {
    var body: some View {
        ContentUnavailableView(
            "Select a repository",
            systemImage: "tray",
            description: Text("Pick a repository to see branches, commits, and status.")
        )
    }
}

#Preview {
    RepositoriesView()
        .environment(AppModel())
}
