import SwiftUI
import TwigCore

struct RepositoryRootsSection: View {
    @Bindable var store: TwigStore

    var body: some View {
        Section("Your repositories") {
            ForEach(store.repositoryRoots, id: \.path) { root in
                let status = store.repositoryStatuses.first { $0.root.path == root.path }
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: status?.isAvailable == false ? "externaldrive.badge.exclamationmark" : "folder")
                        .foregroundStyle(status?.isAvailable == false ? Color.orange : Color.secondary)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(root.lastPathComponent).font(.system(size: 13, weight: .medium))
                        Text(root.path).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle).help(root.path)
                        if let status {
                            if status.isAvailable {
                                Text(status.worktreeCount == 1 ? "1 local checkout" : "\(status.worktreeCount) local checkouts")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text(status.message ?? "Repository unavailable")
                                    .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            Text("Checking repository…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Button { store.removeRepository(root) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                        .help("Remove from Twig; keep all files")
                        .accessibilityLabel("Remove \(root.lastPathComponent) from Twig")
                }
                .padding(.vertical, 3)
            }
            HStack {
                Button("Add Repository…") { store.chooseRepository() }.disabled(store.isAddingRepository)
                if store.isAddingRepository { ProgressView().controlSize(.small) }
                if store.repositoryStatuses.contains(where: { !$0.isAvailable }) {
                    Button("Check Again") { Task { await store.refresh() } }.disabled(store.isRefreshing)
                }
            }
            Text("Add any Git repository to see its main checkout and linked worktrees. Codex worktrees appear automatically.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
