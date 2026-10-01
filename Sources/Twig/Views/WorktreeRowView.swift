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
                HStack(spacing: 11) {
                    Image(systemName: icon).font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary).frame(width: 32)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(shortLabel(item.worktree.repositoryName)).font(.system(size: 13, weight: .semibold))
                                .lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 2)
                            Text(store.activityDate(for: item), style: .relative)
                                .font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
                        }
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.branch").font(.system(size: 10))
                            Text(shortLabel(branchLabel)).font(.system(size: 11, design: .monospaced))
                                .lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 0)
                        }.foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            if store.override(for: item) != nil { Image(systemName: "pin.fill").font(.system(size: 8)) }
                            Text(shortLabel(store.editorName(for: item)))
                            Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .semibold))
                        }.font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    if store.openingID == item.id { ProgressView().controlSize(.mini) }
                }
                .padding(.vertical, 10).padding(.leading, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open \(item.worktree.folder.path)\n\(store.resolution(for: item).reason)")
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
                Image(systemName: "ellipsis").font(.system(size: 14, weight: .medium)).frame(width: 25, height: 32)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .padding(.trailing, 8)
            .help("Worktree actions").accessibilityLabel("Actions for \(item.worktree.repositoryName)")
        }
        .background(hovering ? Color.primary.opacity(0.055) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .onHover { hovering = $0 }
    }

    private var branchLabel: String {
        item.worktree.branch ?? "Detached · \(String((item.worktree.headRevision ?? "unknown").prefix(7)))"
    }

    private var icon: String {
        switch store.resolution(for: item).destination {
        case .finder: "folder"
        case .missingApp: "exclamationmark.app"
        case .ide(let ide): ide == .xcode ? "hammer" : "chevron.left.forwardslash.chevron.right"
        }
    }
}

func shortLabel(_ value: String, limit: Int = 30) -> String {
    value.count > limit ? String(value.prefix(limit - 1)) + "…" : value
}
