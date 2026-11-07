import SwiftUI
import TwigCore

/// Opening actions keep temporary choices separate from saved editor preferences.
struct WorktreeOpeningActions: View {
    let item: ScannedWorktree
    @Bindable var store: TwigStore

    private var installedEditors: [IDEID] {
        IDEID.allCases.filter { store.installed.contains($0) }
    }

    var body: some View {
        Button("Open in \(shortLabel(store.editorName(for: item), limit: 20))") {
            Task { await store.open(item) }
        }
        Menu("Open once with…") {
            ForEach(installedEditors, id: \.self) { ide in
                Button(ide.displayName) { Task { await store.open(item, onceWith: ide) } }
            }
            if installedEditors.isEmpty { Text("No supported editors installed") }
        }
        Button("Open in Terminal") { Task { await store.openTerminal(item) } }
        Divider()
        Menu("Worktree editor") {
            Button { store.setOverride(nil, for: item) } label: {
                choice(store.repositoryEditor(for: item) == nil ? "Automatic" : "Use repository default",
                       selected: store.override(for: item) == nil)
            }
            Divider()
            ForEach(installedEditors, id: \.self) { ide in
                Button { store.setOverride(WorktreeOverride(ide: ide), for: item) } label: {
                    choice(ide.displayName, selected: store.override(for: item)?.ide == ide)
                }
            }
            if let saved = store.override(for: item)?.ide, !store.installed.contains(saved) {
                Label("\(saved.displayName) unavailable", systemImage: "checkmark").disabled(true)
            }
        }
        Menu("Repository editor") {
            Button { store.setRepositoryEditor(nil, for: item) } label: {
                choice("Automatic", selected: store.repositoryEditor(for: item) == nil)
            }
            Divider()
            ForEach(installedEditors, id: \.self) { ide in
                Button { store.setRepositoryEditor(ide, for: item) } label: {
                    choice(ide.displayName, selected: store.repositoryEditor(for: item) == ide)
                }
            }
            if let saved = store.repositoryEditor(for: item), !store.installed.contains(saved) {
                Label("\(saved.displayName) unavailable", systemImage: "checkmark").disabled(true)
            }
        }
    }

    @ViewBuilder private func choice(_ title: String, selected: Bool) -> some View {
        if selected { Label(title, systemImage: "checkmark") }
        else { Text(title) }
    }
}
