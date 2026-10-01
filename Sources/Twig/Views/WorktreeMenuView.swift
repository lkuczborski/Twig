import AppKit
import SwiftUI

struct WorktreeMenuView: View {
    @Bindable var store: TwigStore
    @Environment(\.openSettings) private var openSettings
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider().padding(.top, 12)
            content
            if let message = store.errorMessage {
                errorBanner(message)
            }
            if !store.warnings.isEmpty {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(store.warnings.joined(separator: "\n")).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .help(store.warnings.joined(separator: "\n"))
            }
            Divider()
            footer
        }
        .frame(width: 420)
        .background(.regularMaterial)
        .task { await store.monitor() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 22, weight: .semibold)).foregroundStyle(.green)
                .frame(width: 38, height: 38).background(.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 1) {
                Text("Twig").font(.system(size: 19, weight: .semibold, design: .rounded))
                Text("Pick up where you branched off.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if store.isRefreshing { ProgressView().controlSize(.small) }
            Button { Task { await store.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless).help("Refresh worktrees (⌘R)").keyboardShortcut("r")
            .accessibilityLabel("Refresh worktrees")
        }
        .padding(.horizontal, 18).padding(.top, 17).padding(.bottom, 14)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find a project or branch", text: $store.search)
                .textFieldStyle(.plain).focused($searchFocused)
                .accessibilityLabel("Search worktrees")
                .onSubmit { if let first = store.filteredItems.first { Task { await store.open(first) } } }
            if !store.search.isEmpty {
                Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .font(.system(size: 13)).padding(9)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    @ViewBuilder private var content: some View {
        if store.items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: store.isRefreshing ? "arrow.triangle.branch" : "leaf")
                    .font(.system(size: 34, weight: .light)).foregroundStyle(.secondary)
                Text(store.isRefreshing ? "Finding your worktrees…" : "A fresh place to branch out")
                    .font(.headline)
                Text("Codex worktrees appear here automatically.\nChoose a different Codex home in Settings.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Open Settings…") { NSApp.activate(ignoringOtherApps: true); openSettings() }
            }.frame(maxWidth: .infinity).padding(.vertical, 48)
        } else if store.filteredItems.isEmpty {
            ContentUnavailableView.search(text: store.search).frame(height: 240)
        } else {
            HStack {
                Text("RECENT WORKTREES").font(.system(size: 10, weight: .semibold)).tracking(1.1)
                Spacer()
                Text("\(store.filteredItems.count)").font(.caption.monospacedDigit())
            }
            .foregroundStyle(.secondary).padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 6)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.filteredItems) { item in WorktreeRowView(item: item, store: store) }
                }.padding(.horizontal, 8).padding(.bottom, 10)
            }
            .frame(height: min(420, CGFloat(store.filteredItems.count) * 79 + 10))
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Circle().fill(.green).frame(width: 5, height: 5)
            Text(store.isRefreshing ? "Refreshing…" : "Local · refreshes every 30s").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button { NSApp.activate(ignoringOtherApps: true); openSettings() } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless).keyboardShortcut(",").help("Settings (⌘,)").accessibilityLabel("Settings")
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless).font(.caption).foregroundStyle(.secondary).keyboardShortcut("q")
        }.padding(.horizontal, 18).padding(.vertical, 12)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).textSelection(.enabled)
            Spacer(minLength: 0)
            Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).accessibilityLabel("Dismiss error")
        }.padding(12).background(.orange.opacity(0.08))
    }
}
