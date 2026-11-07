import AppKit
import SwiftUI

struct WelcomeView: View {
    @Bindable var store: TwigStore
    let showSettings: () -> Void
    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 18) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable().frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to Twig").font(.system(size: 25, weight: .semibold))
                    Text("Your worktrees. The right editor.\nOne click away.")
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(.top, 7)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(discoveryTitle, systemImage: store.items.isEmpty ? "folder" : "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(store.items.isEmpty ? Color.secondary : Color.accentColor)
                    Spacer()
                    if store.isRefreshing { ProgressView().controlSize(.small) }
                }
                if store.items.isEmpty {
                    Text("Twig finds your local Codex worktrees automatically. Choose your Codex folder if you keep them somewhere else.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Choose a folder…", action: showSettings)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(store.sortedItems) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.triangle.branch").foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.worktree.repositoryName).font(.system(size: 13, weight: .medium))
                                        Text(item.worktree.branch ?? "Detached worktree")
                                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                                            .lineLimit(1).truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(store.editorName(for: item)).font(.caption).foregroundStyle(.secondary)
                                }.frame(minHeight: 34)
                            }
                        }
                    }
                    .scrollIndicators(.visible)
                    .frame(height: min(154, CGFloat(store.items.count) * 48 - 14))
                    .accessibilityLabel("Detected worktrees")
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "menubar.arrow.up.rectangle").font(.title2).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find the branch in your menu bar").font(.system(size: 13, weight: .medium))
                    Text("Search for a project or branch, then press Return to open it in the right editor.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }

            LoginItemSettingsView()
            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.orange).lineLimit(3)
            }
            if store.preferencesNeedRecovery {
                Button("Recover Preferences in Settings…", action: showSettings)
            }
            Divider()
            HStack {
                Label("Local. Private. Yours.", systemImage: "lock")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Open Twig", action: finish)
                    .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
            }
        }
        .padding(30).frame(width: 520)
        .background(.regularMaterial)
        .background(WindowVisibilityObserver { visible in
            store.contentVisibilityChanged("welcome", isVisible: visible)
        }.frame(width: 0, height: 0))
        .task { await store.refresh() }
    }

    private var discoveryTitle: String {
        if store.isRefreshing && store.items.isEmpty { return "Finding your worktrees…" }
        if store.items.isEmpty { return "Let’s find your worktrees" }
        return "\(store.items.count) worktree\(store.items.count == 1 ? "" : "s") ready to open"
    }
}
