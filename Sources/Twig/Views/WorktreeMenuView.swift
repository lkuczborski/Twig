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
            DispatchQueue.main.async { searchFocused = visible }
        }.frame(width: 0, height: 0))
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
            TextField("Search worktrees", text: $store.search)
                .textFieldStyle(.plain).accessibilityLabel("Search worktrees")
                .focused($searchFocused)
                .onSubmit { if let first = store.visibleItems.first { Task { await store.open(first) } } }
            if !store.search.isEmpty {
                Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
            if store.isRefreshing { ProgressView().controlSize(.mini) }
            Menu {
                Toggle("Group by repository", isOn: Binding(
                    get: { store.preferences.groupByRepository },
                    set: { store.setGroupByRepository($0) }
                ))
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
        let byID = Dictionary(uniqueKeysWithValues: store.filteredItems.map { ($0.id, $0) })
        return ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(store.worktreeSections) { section in
                    if let title = section.title {
                        sectionHeader(title, section: section)
                    }
                    ForEach(section.worktrees) { worktree in
                        if let item = byID[worktree.id] {
                            WorktreeRowView(item: item, store: store, showDetails: showDetails,
                                            isRepositoryGroup: section.isRepositoryGroup)
                        }
                    }
                }
            }.padding(5)
        }
        // Search changes the contents, not the panel's size. Keeping the scroll
        // container alive also preserves the hosting window's layout and clipping.
        .frame(height: contentHeight)
        .overlay {
            if store.filteredItems.isEmpty { emptyState }
        }
    }

    private var contentHeight: CGFloat {
        // Size from the unfiltered catalog to keep the search field anchored.
        let sections = WorktreeOrganization.sections(store.sortedItems.map(\.worktree),
                                                     pinnedIDs: store.preferences.pinnedWorktrees,
                                                     groupByRepository: store.preferences.groupByRepository)
        let headerCount = sections.filter { $0.title != nil }.count
        return store.items.isEmpty ? 130 : min(400, CGFloat(store.items.count) * 53 + CGFloat(headerCount) * 27 + 10)
    }

    private func sectionHeader(_ title: String, section: WorktreeSection) -> some View {
        HStack(spacing: 5) {
            if section.id == "pinned" { Image(systemName: "pin.fill").font(.system(size: 9)) }
            Text(title).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            Text("\(section.worktrees.count)").monospacedDigit().foregroundStyle(.tertiary)
        }
        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 4)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var emptyState: some View {
        if store.items.isEmpty {
            VStack(spacing: 8) {
                if store.isRefreshing {
                    Text("Loading worktrees…").foregroundStyle(.secondary)
                } else {
                    Text("No worktrees").font(.system(size: 13, weight: .medium))
                    Text("Choose your Codex folder in Settings.").font(.caption).foregroundStyle(.secondary)
                    Button("Settings…") { showSettings() }
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

struct MenuPresentationActions {
    let showSettings: () -> Void
    let showDetails: () -> Void
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
