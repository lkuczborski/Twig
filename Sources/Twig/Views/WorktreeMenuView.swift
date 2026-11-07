import AppKit
import SwiftUI
import TwigCore

struct WorktreeMenuView: View {
    @Bindable var store: TwigStore
    let presentation: MenuPresentationActions
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
            if let message = store.errorMessage { errorBanner(message) }
            if !store.warnings.isEmpty {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(store.warnings.joined(separator: "\n")).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .help(store.warnings.joined(separator: "\n"))
            }
        }
        .frame(width: 360)
        .modifier(MenuGlassBackground())
        .background(WindowVisibilityObserver { visible in
            store.contentVisibilityChanged("menu", isVisible: visible)
            DispatchQueue.main.async {
                searchFocused = visible
                if visible { store.reconcileHighlight() }
            }
        }.frame(width: 0, height: 0))
        .background(MenuKeyboardHandler(
            onMove: store.moveHighlight,
            onOpen: { Task { await store.openHighlighted() } },
            onPrevious: { Task { await store.openPrevious() } },
            onDismiss: presentation.dismiss
        ).frame(width: 0, height: 0))
        .onChange(of: store.search) { _, _ in
            store.highlightedID = nil
            store.reconcileHighlight()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
            TextField("Search worktrees", text: $store.search)
                .textFieldStyle(.plain).accessibilityLabel("Search worktrees")
                .focused($searchFocused)
                .onSubmit { Task { await store.openHighlighted() } }
            if !store.search.isEmpty {
                Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
            if store.isRefreshing { ProgressView().controlSize(.mini) }
            Menu {
                Button("Open Previous Worktree") { Task { await store.openPrevious() } }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .disabled(store.previousItem == nil)
                Button("Add Repository…") { store.chooseRepository() }.disabled(store.isAddingRepository)
                Divider()
                Button("Refresh") { Task { await store.refresh() } }.keyboardShortcut("r")
                Divider()
                Button("Settings…") { showSettings() }.keyboardShortcut(",")
                Button("Quit Twig") { NSApp.terminate(nil) }.keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape").foregroundStyle(.secondary).frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel("Twig actions")
        }
        .font(.system(size: 13)).padding(.horizontal, 12).padding(.vertical, 9)
    }

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(menuEntries) { entry in
                        if let item = entry.item {
                            WorktreeRowView(item: item, store: store, showDetails: showDetails,
                                            isRepositoryGroup: entry.section.isRepositoryGroup)
                                .id(item.id)
                        } else if let title = entry.section.title {
                            sectionHeader(title, section: entry.section)
                        }
                    }
                }.padding(5)
            }
            .onChange(of: store.highlightedID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
            .onChange(of: store.preferences.sortOrder) { _, _ in
                if let id = store.highlightedID { proxy.scrollTo(id) }
            }
        }
        // Search changes the contents, not the panel's size. Keeping the scroll
        // container alive also preserves the hosting window's layout and clipping.
        .frame(height: contentHeight)
        .overlay {
            if store.filteredItems.isEmpty { emptyState }
        }
    }

    // One flat sequence gives every lazy row a stable, unique identity when it
    // moves between pinned, repository, and search-result sections.
    private var menuEntries: [WorktreeMenuEntry] {
        let byID = Dictionary(uniqueKeysWithValues: store.filteredItems.map { ($0.id, $0) })
        return store.worktreeSections.flatMap { section in
            let header = section.title == nil ? [] : [WorktreeMenuEntry(id: "header:\(section.id)", section: section, item: nil)]
            return header + section.worktrees.compactMap { worktree in
                byID[worktree.id].map { WorktreeMenuEntry(id: $0.id, section: section, item: $0) }
            }
        }
    }

    private var contentHeight: CGFloat {
        // Size from the unfiltered catalog to keep the search field anchored.
        let sections = store.catalogSections
        let headerCount = sections.filter { $0.title != nil }.count
        return store.items.isEmpty ? 130 : min(400, CGFloat(store.items.count) * 53 + CGFloat(headerCount) * 31 + 10)
    }

    private func sectionHeader(_ title: String, section: WorktreeSection) -> some View {
        HStack(spacing: 8) {
            if section.id == "pinned" {
                Image(systemName: "pin.fill").font(.system(size: 10)).accessibilityHidden(true)
            }
            Text(title).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            Text("\(section.worktrees.count)").font(.system(size: 10, weight: .medium))
                .monospacedDigit().foregroundStyle(.secondary)
                .accessibilityLabel(section.worktrees.count == 1 ? "1 worktree" : "\(section.worktrees.count) worktrees")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        .padding(.horizontal, 8).padding(.top, 12).padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var emptyState: some View {
        if store.items.isEmpty {
            VStack(spacing: 8) {
                if store.isRefreshing {
                    Text("Loading worktrees…").foregroundStyle(.secondary)
                } else {
                    Text("No worktrees").font(.system(size: 13, weight: .medium))
                    Text("Add a Git repository or choose your Codex folder.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Add Repository…") { store.chooseRepository() }.disabled(store.isAddingRepository)
                        Button("Settings…") { showSettings() }
                    }
                }
            }.frame(maxWidth: .infinity)
        } else {
            Text("No matching worktrees").font(.system(size: 13)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func showSettings() {
        presentation.showSettings()
    }

    private func showDetails() {
        presentation.showDetails()
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).textSelection(.enabled)
            Spacer(minLength: 0)
            Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).accessibilityLabel("Dismiss error")
        }.padding(10).background(.orange.opacity(0.08))
    }
}

private struct WorktreeMenuEntry: Identifiable {
    let id: String
    let section: WorktreeSection
    let item: ScannedWorktree?
}

struct MenuPresentationActions {
    let showSettings: () -> Void
    let showDetails: () -> Void
    var dismiss: () -> Void = {}
}

/// One glass surface samples the desktop directly through the transparent panel.
private struct MenuGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                .clipShape(.rect(cornerRadius: 14))
                .containerBackground(.clear, for: .window)
        } else {
            content.background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        }
    }
}
