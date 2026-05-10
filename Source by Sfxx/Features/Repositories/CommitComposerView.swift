import SwiftUI

struct CommitComposerView: View {
    @Binding var message: String
    @Binding var amend: Bool
    @Binding var sign: Bool
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Commit")
                .font(.headline)

            TextField("Commit message", text: $message, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            Toggle("Amend previous commit", isOn: $amend)
            Toggle("Sign commit", isOn: $sign)

            Button {
                onCommit()
            } label: {
                Label("Commit Changes", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

#Preview {
    CommitComposerView(
        message: .constant("Add commit flow"),
        amend: .constant(false),
        sign: .constant(false),
        onCommit: {}
    )
    .padding()
}
