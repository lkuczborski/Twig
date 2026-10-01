import AppKit
import SwiftUI

struct WorktreeMenuView: View {
    @Bindable var store: TwigStore
    @Environment(\.openSettings) private var openSettings

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
        }.frame(width: 0, height: 0))
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
            TextField("Search worktrees", text: $store.search)
                .textFieldStyle(.plain).accessibilityLabel("Search worktrees")
                .onSubmit { if let first = store.filteredItems.first { Task { await store.open(first) } } }
            if !store.search.isEmpty {
                Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
            if store.isRefreshing { ProgressView().controlSize(.mini) }
            Menu {
                Button("Refresh") { Task { await store.refresh() } }.keyboardShortcut("r")
                Divider()
                Button("Settings…") { NSApp.activate(ignoringOtherApps: true); openSettings() }.keyboardShortcut(",")
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
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(store.filteredItems) { item in WorktreeRowView(item: item, store: store) }
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
        store.items.isEmpty ? 130 : min(400, CGFloat(store.items.count) * 53 + 10)
    }

    @ViewBuilder private var emptyState: some View {
        if store.items.isEmpty {
            VStack(spacing: 8) {
                if store.isRefreshing {
                    Text("Loading worktrees…").foregroundStyle(.secondary)
                } else {
                    Text("No worktrees").font(.system(size: 13, weight: .medium))
                    Text("Choose your Codex folder in Settings.").font(.caption).foregroundStyle(.secondary)
                    Button("Settings…") { NSApp.activate(ignoringOtherApps: true); openSettings() }
                }
            }.frame(maxWidth: .infinity)
        } else {
            Text("No matching worktrees").font(.system(size: 13)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
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

/// Apply glass at the window boundary so the entire popover shares one surface.
/// Older systems retain MenuBarExtra's native material.
private struct MenuGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .background(.ultraThinMaterial)
                .glassEffect(.clear, in: .rect(cornerRadius: 14))
                .clipShape(.rect(cornerRadius: 14))
                .containerBackground(.clear, for: .window)
        } else {
            content
        }
    }
}
