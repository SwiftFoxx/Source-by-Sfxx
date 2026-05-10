import SwiftUI

struct BranchesListView: View {
    let branches: [Branch]
    let onCheckout: (Branch) -> Void
    let onCreate: (String) -> Void
    let onDelete: (Branch) -> Void

    @State private var newBranch = ""
    @State private var deleteTarget: Branch?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Branches")
                .font(.headline)

            HStack {
                TextField("New branch", text: $newBranch)
                    .textFieldStyle(.roundedBorder)

                Button("Create") {
                    let trimmed = newBranch.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onCreate(trimmed)
                    newBranch = ""
                }
                .buttonStyle(.borderedProminent)
            }

            if branches.isEmpty {
                Text("No branches loaded yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(branches) { branch in
                    HStack {
                        Text(branch.name)
                            .font(.subheadline.weight(branch.isCurrent ? .semibold : .regular))
                        Spacer()
                        if branch.isCurrent {
                            StatusPill(text: "Current", tint: .blue)
                        }
                        Button("Checkout") {
                            onCheckout(branch)
                        }
                        .buttonStyle(.bordered)
                        .disabled(branch.isCurrent)

                        Button(role: .destructive) {
                            deleteTarget = branch
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(branch.isCurrent)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .alert("Delete Branch", isPresented: hasDeleteTarget) {
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
            Button("Delete", role: .destructive) {
                if let branch = deleteTarget {
                    onDelete(branch)
                }
                deleteTarget = nil
            }
        } message: {
            Text("This will delete the branch locally.")
        }
    }

    private var hasDeleteTarget: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }
}
