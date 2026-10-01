import AppKit
import SwiftUI
import TwigCore

struct TwigSettingsView: View {
    @Bindable var store: TwigStore
    @State private var codexPath = ""
    @State private var confirmRecovery = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "arrow.triangle.branch").font(.largeTitle).foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Twig").font(.title2.bold())
                        Text("Your worktrees, one click away.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("0.1.0").font(.caption).foregroundStyle(.tertiary)
                }.padding(.vertical, 5)
            }
            Section("Worktree discovery") {
                TextField("Codex home", text: $codexPath, prompt: Text("Automatic (~/.codex)"))
                HStack {
                    Button("Choose Folder…") { chooseFolder() }
                    Button("Apply") { store.setCodexHome(codexPath) }
                    Button("Use Default") { codexPath = ""; store.setCodexHome("") }
                }
                Text("Active folder: \(store.codexHome.path)\nTwig reads its worktrees folder and checks for changes every 30 seconds while open.")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Section("Opening projects") {
                Picker("Fallback editor", selection: Binding(get: { store.preferences.fallbackIDE }, set: { store.setFallback($0) })) {
                    Text("Automatic").tag(Optional<IDEID>.none)
                    ForEach(IDEID.allCases.filter { store.installed.contains($0) }, id: \.self) { ide in
                        Text(ide.displayName).tag(Optional(ide))
                    }
                    if let fallback = store.preferences.fallbackIDE, !store.installed.contains(fallback) {
                        Text("\(fallback.displayName) (unavailable)").tag(Optional(fallback))
                    }
                }
                Text("Used when no installed editor matches the detected project. Automatic tries an installed general editor, then Finder. Each worktree’s choice takes priority.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Check Installed Editors") { Task { await store.refreshApplications() } }
            }
            Section {
                Text("Twig runs locally. It reads project filenames and small configuration snippets, never runs project code, and doesn’t read Codex conversations.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = store.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                    Button("Dismiss Error") { store.errorMessage = nil }
                }
                if store.preferencesNeedRecovery {
                    Button("Recover Saved Preferences…") { confirmRecovery = true }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 530, height: 550)
        .onAppear { codexPath = store.preferences.codexHome ?? "" }
        .task { await store.refreshApplications() }
        .confirmationDialog("Reset unreadable preferences?", isPresented: $confirmRecovery) {
            Button("Back Up & Reset") { store.recoverPreferences(); codexPath = "" }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Twig will keep a backup of the original file and restore default settings. Your worktrees are unaffected.")
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Codex home"
        panel.message = "Choose the folder that contains Codex’s worktrees directory."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = store.codexHome
        if panel.runModal() == .OK, let url = panel.url {
            codexPath = url.path
            store.setCodexHome(codexPath)
        }
    }
}
