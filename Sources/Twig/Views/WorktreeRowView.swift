import AppKit
import SwiftUI
import TwigCore

struct WorktreeRowView: View {
    let item: ScannedWorktree
    @Bindable var store: TwigStore
    @Environment(\.openWindow) private var openWindow
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            Button { Task { await store.open(item) } } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(shortLabel(item.worktree.repositoryName))
                            .font(.system(size: 13, weight: .medium)).lineLimit(1).truncationMode(.middle)
                        Text(shortLabel(branchLabel))
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                    if store.openingID == item.id { ProgressView().controlSize(.mini) }
                }
                .padding(.vertical, 8).padding(.leading, 8)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open in \(store.editorName(for: item))\n\(branchLabel)\n\(item.worktree.folder.path)\n\(store.resolution(for: item).reason)")
            .accessibilityLabel("Open \(item.worktree.repositoryName), \(branchLabel), in \(store.editorName(for: item))")

            Menu {
                Button("Open in \(shortLabel(store.editorName(for: item), limit: 20))") { Task { await store.open(item) } }
                Menu("Always open with") {
                    Button {
                        store.setOverride(nil, for: item)
                    } label: {
                        Label("Automatic", systemImage: store.override(for: item) == nil ? "checkmark" : "sparkles")
                    }
                    Divider()
                    ForEach(IDEID.allCases.filter { store.installed.contains($0) }, id: \.self) { ide in
                        Button {
                            store.setOverride(WorktreeOverride(ide: ide), for: item)
                        } label: {
                            if store.override(for: item)?.ide == ide {
                                Label(ide.displayName, systemImage: "checkmark")
                            } else { Text(ide.displayName) }
                        }
                    }
                    if store.installed.isEmpty { Text("No supported IDEs installed") }
                }
                Button("Project & detection details…") {
                    store.selectedID = item.id
                    openWindow(id: "details")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Divider()
                Button("Open folder in Finder") { store.openFolder(item) }
                Button("Open enclosing folder") { store.reveal(item) }
                Button("Copy folder path") { store.copyPath(item) }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 14, weight: .medium)).frame(width: 22, height: 24)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .foregroundStyle(.secondary).padding(.trailing, 5)
            .help("Worktree actions").accessibilityLabel("Actions for \(item.worktree.repositoryName)")
        }
        .background(hovering ? Color.primary.opacity(0.055) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        .onHover { hovering = $0 }
    }

    private var branchLabel: String {
        item.worktree.branch ?? "Detached · \(String((item.worktree.headRevision ?? "unknown").prefix(7)))"
    }

}

func shortLabel(_ value: String, limit: Int = 30) -> String {
    value.count > limit ? String(value.prefix(limit - 1)) + "…" : value
}
