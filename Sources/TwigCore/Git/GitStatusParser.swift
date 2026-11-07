import Foundation

public struct GitWorktreeStatus: Hashable, Sendable {
    public let changedFileCount: Int
    public let conflictedFileCount: Int
    public let aheadCount: Int?
    public let behindCount: Int?

    public init(changedFileCount: Int, conflictedFileCount: Int, aheadCount: Int?, behindCount: Int?) {
        self.changedFileCount = changedFileCount
        self.conflictedFileCount = conflictedFileCount
        self.aheadCount = aheadCount
        self.behindCount = behindCount
    }
}

public enum GitStatusResult: Hashable, Sendable {
    case available(GitWorktreeStatus)
    case unavailable
}

/// Parses NUL-delimited porcelain without interpreting or decoding filenames.
enum GitStatusParser {
    static func parse(_ output: Data) -> GitWorktreeStatus? {
        guard output.last == 0 else { return nil }
        let records = output.dropLast().split(separator: 0, omittingEmptySubsequences: false)
        var changed = Set<Data>()
        var conflicted = Set<Data>()
        var head: String?
        var revision: String?
        var upstream = false
        var divergence: (Int, Int)?
        var index = 0

        while index < records.count {
            let record = records[index]
            index += 1
            guard let kind = record.first else { return nil }
            if kind == 35 { // #
                guard let header = String(data: Data(record), encoding: .utf8) else { return nil }
                if header.hasPrefix("# branch.head ") {
                    head = String(header.dropFirst(14))
                } else if header.hasPrefix("# branch.oid ") {
                    revision = String(header.dropFirst(13))
                } else if header.hasPrefix("# branch.upstream ") {
                    upstream = !header.dropFirst(18).isEmpty
                } else if header.hasPrefix("# branch.ab ") {
                    let counts = header.dropFirst(12).split(separator: " ")
                    guard counts.count == 2, counts[0].first == "+", counts[1].first == "-",
                          let ahead = Int(counts[0].dropFirst()), let behind = Int(counts[1].dropFirst()),
                          ahead >= 0, behind >= 0 else { return nil }
                    divergence = (ahead, behind)
                }
                continue
            }

            let fieldCount: Int
            switch kind {
            case 49: fieldCount = 8 // ordinary entry
            case 50: fieldCount = 9 // rename/copy, followed by original path
            case 117: fieldCount = 10 // unmerged entry
            case 63, 33: fieldCount = 1 // untracked / ignored
            default: return nil
            }
            let fields = record.split(separator: 32, maxSplits: fieldCount, omittingEmptySubsequences: false)
            guard fields.count == fieldCount + 1, !fields.last!.isEmpty else { return nil }
            if fieldCount > 1 {
                guard fields[1].count == 2 else { return nil }
            }
            if kind == 50 {
                guard index < records.count, !records[index].isEmpty else { return nil }
                index += 1
            }
            if kind != 33 {
                let path = Data(fields.last!)
                changed.insert(path)
                if kind == 117 { conflicted.insert(path) }
            }
        }
        guard let head, !head.isEmpty, let revision, !revision.isEmpty else { return nil }
        let hasUpstream = upstream && head != "(detached)" && revision != "(initial)"
        // A missing branch.ab (for example a deleted upstream ref) is unknown, not zero.
        return GitWorktreeStatus(
            changedFileCount: changed.count,
            conflictedFileCount: conflicted.count,
            aheadCount: hasUpstream ? divergence?.0 : nil,
            behindCount: hasUpstream ? divergence?.1 : nil
        )
    }
}
