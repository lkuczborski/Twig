import SwiftUI
import TwigCore

/// One secondary line, with lower-priority context removed before branch identity or conflicts.
struct WorktreeMetadataView: View {
    let identity: String?
    let projectType: String?
    let opened: String?
    let git: WorktreeGitSummary

    var body: some View {
        ViewThatFits(in: .horizontal) {
            metadata(context: joined(identity, projectType, opened), includeSync: true)
                .fixedSize(horizontal: true, vertical: false)
            metadata(context: joined(identity, projectType), includeSync: true)
                .fixedSize(horizontal: true, vertical: false)
            metadata(context: identity, includeSync: true)
                .fixedSize(horizontal: true, vertical: false)
            metadata(context: identity ?? projectType ?? opened, includeSync: false)
                .fixedSize(horizontal: true, vertical: false)
            // The final candidate can truncate a long branch, but keeps its distinctive ending.
            metadata(context: identity ?? projectType ?? opened, includeSync: false)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 14, maxHeight: 14, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func joined(_ values: String?...) -> String? {
        let text = values.compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }

    private func metadata(context: String?, includeSync: Bool) -> some View {
        HStack(spacing: 5) {
            if let context {
                Text(context).lineLimit(1).truncationMode(.middle)
            }
            if let primary = git.primary {
                if context != nil { Text("·").foregroundStyle(.tertiary).fixedSize() }
                if git.hasConflicts {
                    Label(primary, systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.titleAndIcon).foregroundStyle(.red).fixedSize()
                } else {
                    Text(primary).monospacedDigit().fixedSize()
                }
            }
            if includeSync, let sync = git.sync {
                if context != nil || git.primary != nil { Text("·").foregroundStyle(.tertiary).fixedSize() }
                Text(sync).monospacedDigit().fixedSize()
            }
            if context == nil && git.primary == nil && (!includeSync || git.sync == nil) {
                Text(git.fallback).lineLimit(1).truncationMode(.tail)
            }
        }
    }
}

/// Human-readable Git facts. Upstream counts describe local refs and never imply a network refresh.
struct WorktreeGitSummary {
    let primary: String?
    let sync: String?
    let fallback: String
    let description: String
    let hasConflicts: Bool

    init(_ result: GitStatusResult?) {
        guard let result else {
            primary = nil
            sync = nil
            fallback = "Checking Git status…"
            description = fallback
            hasConflicts = false
            return
        }
        switch result {
        case .unavailable:
            primary = "Git unavailable"
            sync = nil
            fallback = "Git status unavailable"
            description = fallback
            hasConflicts = false
        case .available(let status):
            hasConflicts = status.conflictedFileCount > 0
            if hasConflicts {
                primary = "\(status.conflictedFileCount) conflict\(status.conflictedFileCount == 1 ? "" : "s")"
            } else if status.changedFileCount > 0 {
                primary = "\(status.changedFileCount) changed"
            } else {
                primary = nil
            }
            var counts: [String] = []
            if let ahead = status.aheadCount, ahead > 0 { counts.append("↑\(ahead)") }
            if let behind = status.behindCount, behind > 0 { counts.append("↓\(behind)") }
            sync = counts.isEmpty ? nil : counts.joined(separator: " ")
            fallback = "No local changes"
            var details = [status.changedFileCount == 0 ? "No local changes"
                : "\(status.changedFileCount) changed file\(status.changedFileCount == 1 ? "" : "s")"]
            if hasConflicts {
                details.append("\(status.conflictedFileCount) conflicted file\(status.conflictedFileCount == 1 ? "" : "s")")
            }
            if let ahead = status.aheadCount, let behind = status.behindCount {
                details.append("\(ahead) ahead, \(behind) behind the locally known upstream (no fetch)")
            } else {
                details.append("No upstream comparison available")
            }
            description = details.joined(separator: " · ")
        }
    }
}
