import SwiftUI
import TwigCore

struct WorktreeOrganizationControls: View {
    let item: ScannedWorktree
    @Bindable var store: TwigStore
    @State private var draftLabel = ""

    var body: some View {
        GroupBox("Make it yours") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("Personal label", text: $draftLabel, prompt: Text("e.g. Login redesign"))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Personal worktree label")
                        .onSubmit(saveLabel)
                    Button("Save", action: saveLabel)
                        .disabled(draftLabel == (store.label(for: item) ?? ""))
                    if store.label(for: item) != nil {
                        Button("Clear") {
                            if store.setLabel("", for: item) { draftLabel = "" }
                        }
                    }
                }
                Text("A label only changes how this worktree appears in Twig.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Pin to the top", isOn: Binding(
                    get: { store.isPinned(item) },
                    set: { value in if value != store.isPinned(item) { store.togglePin(item) } }
                ))
                .toggleStyle(.checkbox)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
        .onAppear { draftLabel = store.label(for: item) ?? "" }
        .onChange(of: item.id) { _, _ in draftLabel = store.label(for: item) ?? "" }
    }

    private func saveLabel() {
        if store.setLabel(draftLabel, for: item) { draftLabel = store.label(for: item) ?? "" }
    }
}
