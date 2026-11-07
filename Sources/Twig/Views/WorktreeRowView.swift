import AppKit
import SwiftUI
import TwigCore

struct WorktreeRowView: View {
    let item: ScannedWorktree
    @Bindable var store: TwigStore
    let showDetails: () -> Void
    var isRepositoryGroup = false
    @State private var hovering = false

    var body: some View {
        let resolution = store.resolution(for: item)
        let projectType = WorktreePresentation.projectType(detection: item.detection, resolution: resolution)
        let lastOpened = store.preferences.lastOpenedDate(for: item.worktree.folder)
        let opened = WorktreePresentation.lastOpenedLabel(lastOpened)
        let git = WorktreeGitSummary(store.gitStatus(for: item))
        let metadataDescription = [projectType, lastOpened.map { "Last opened \($0.formatted(date: .abbreviated, time: .shortened))" }, git.description]
            .compactMap { $0 }.joined(separator: "\n")
        HStack(spacing: 5) {
            Button {
                // Read modifiers synchronously; the key may be released before an async task starts.
                let modifiers = NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags
                if modifiers.contains(.option) {
                    store.openFolder(item)
                } else {
                    Task { await store.open(item) }
                }
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(rowTitle)
                            .font(.system(size: 13, weight: .medium)).lineLimit(1).truncationMode(.middle)
                        WorktreeMetadataView(identity: secondaryIdentity, projectType: projectType,
                                             opened: opened, git: git)
                    }
                    Spacer(minLength: 0)
                    editorIndicator(resolution.destination)
                }
                .padding(.vertical, 8).padding(.leading, 8)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("\(launchDescription(resolution.destination))\n\(branchLabel)\n\(metadataDescription)\n\(item.worktree.folder.path)\n\(resolution.reason)\nOption-click to open folder in Finder")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Open \(store.displayTitle(for: item)), \(item.worktree.repositoryName), \(branchLabel), in \(store.editorName(for: item))")
            .accessibilityValue(metadataDescription)

            Menu {
                WorktreeOpeningActions(item: item, store: store)
                Divider()
                Button {
                    store.togglePin(item)
                } label: {
                    Label(store.isPinned(item) ? "Unpin worktree" : "Pin worktree", systemImage: store.isPinned(item) ? "pin.slash" : "pin")
                }
                Button("Edit label…") {
                    store.selectedID = item.id
                    showDetails()
                }
                Divider()
                Button("Project & detection details…") {
                    store.selectedID = item.id
                    showDetails()
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
            .help("Worktree actions").accessibilityLabel("Actions for \(store.displayTitle(for: item))")
        }
        .background(store.highlightedID == item.id ? Color.accentColor.opacity(0.16) :
                    hovering ? Color.primary.opacity(0.055) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        .accessibilityAddTraits(store.highlightedID == item.id ? .isSelected : [])
        .onHover { hovering = $0 }
    }

    private var branchLabel: String {
        item.worktree.branch ?? "Detached · \(String((item.worktree.headRevision ?? "unknown").prefix(7)))"
    }

    private var rowTitle: String {
        store.label(for: item) ?? (isRepositoryGroup ? branchLabel : item.worktree.repositoryName)
    }

    private var secondaryIdentity: String? {
        guard !isRepositoryGroup || store.label(for: item) != nil else { return nil }
        return store.label(for: item) != nil && !isRepositoryGroup
            ? "\(item.worktree.repositoryName) · \(branchLabel)" : branchLabel
    }

    private func launchDescription(_ destination: LaunchDestination) -> String {
        switch destination {
        case .ide(let ide): "Open in \(ide.displayName)"
        case .missingApp(let ide): "\(ide.displayName) is unavailable"
        case .finder: "Open in Finder"
        }
    }

    private func editorIndicator(_ destination: LaunchDestination) -> some View {
        ZStack {
            if store.openingID == item.id {
                ProgressView().controlSize(.mini)
            } else if case .missingApp = destination {
                Image(systemName: "exclamationmark.square").foregroundStyle(.orange)
            } else if let icon = store.editorIcon(for: item) {
                Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: destination == .finder ? "folder" : "app.dashed")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 20, height: 20)
        .help(launchDescription(destination))
        .accessibilityHidden(true)
    }

}

func shortLabel(_ value: String, limit: Int = 30) -> String {
    value.count > limit ? String(value.prefix(limit - 1)) + "…" : value
}
