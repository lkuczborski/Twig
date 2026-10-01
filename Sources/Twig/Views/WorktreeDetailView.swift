import SwiftUI
import TwigCore

struct WorktreeDetailView: View {
    @Bindable var store: TwigStore

    var body: some View {
        Group {
            if let item = store.selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 7) {
                            Label(item.worktree.repositoryName, systemImage: "arrow.triangle.branch").font(.title2.bold())
                            Text(item.worktree.branch ?? "Detached HEAD · \(item.worktree.headRevision ?? "Unknown commit")")
                                .font(.body.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                            Text(item.worktree.folder.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        GroupBox("Click to open") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(store.editorName(for: item)).font(.headline)
                                    Spacer()
                                    Button("Open") { Task { await store.open(item) } }.keyboardShortcut(.return)
                                }
                                Text(store.resolution(for: item).reason).font(.callout).foregroundStyle(.secondary)
                                Text(store.resolution(for: item).target.path).font(.caption.monospaced()).textSelection(.enabled)
                                if store.override(for: item) != nil {
                                    Button("Restore Automatic") { store.setOverride(nil, for: item) }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Detected projects").font(.headline)
                            Text("Project files suggest an editor. Choose a target below to remember it for this worktree.")
                                .font(.callout).foregroundStyle(.secondary)
                            ForEach(item.detection.candidates) { candidate in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(candidate.ide.displayName).font(.system(size: 13, weight: .semibold))
                                            Text(candidate.projectKind).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if store.installed.contains(candidate.ide) {
                                            Button("Use this target") {
                                                store.setOverride(WorktreeOverride(ide: candidate.ide, targetPath: candidate.target.path), for: item)
                                            }
                                        } else {
                                            Text("Not installed").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Text(candidate.reason).font(.caption).foregroundStyle(.secondary)
                                    Text(candidate.target.path).font(.caption2.monospaced()).foregroundStyle(.tertiary).textSelection(.enabled)
                                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                            }
                            Text("Inspected \(item.detection.scannedFileCount) entries\(item.detection.wasTruncated ? " · scan limit reached" : "") · no project code is executed")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let error = store.errorMessage { Text(error).font(.callout).foregroundStyle(.orange).textSelection(.enabled) }
                    }.padding(24)
                }
            } else {
                ContentUnavailableView("Choose a worktree", systemImage: "arrow.triangle.branch",
                                       description: Text("Open a worktree’s actions menu and select Project & detection details."))
            }
        }.frame(minWidth: 480, minHeight: 420)
    }
}
