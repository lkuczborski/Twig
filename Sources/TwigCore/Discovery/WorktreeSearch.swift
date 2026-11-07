import Foundation

public enum WorktreeSearch {
    /// Exact words and contiguous matches rank ahead of subsequences. All tokens must match.
    public static func score(query: String, fields: [String], literalFields: [String] = []) -> Int? {
        let tokens = normalized(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return 0 }
        let fields = fields.map(normalized)
        let literalFields = literalFields.map(normalized)
        var total = 0
        for token in tokens {
            let matches = fields.compactMap { match(token, in: $0) }
                + literalFields.compactMap { match(token, in: $0, allowingFuzzy: false) }
            guard let best = matches.max() else { return nil }
            total += best
        }
        return total
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func match(_ token: String, in field: String, allowingFuzzy: Bool = true) -> Int? {
        if field == token { return 10_000 }
        if field.hasPrefix(token) { return 8_000 - min(field.count, 1_000) }
        if let range = field.range(of: token) {
            let boundary = range.lowerBound == field.startIndex || !field[field.index(before: range.lowerBound)].isLetter
            return (boundary ? 6_000 : 5_000) - min(field.count, 1_000)
        }
        // Absolute filesystem prefixes contain many unrelated letters. Match paths literally,
        // while keeping fuzzy abbreviations useful for project names and branches.
        guard allowingFuzzy else { return nil }
        let characters = Array(field)
        var cursor = 0
        var first: Int?
        var last = 0
        var adjacency = 0
        for character in token {
            guard let index = characters[cursor...].firstIndex(of: character) else { return nil }
            if first == nil { first = index }
            else if index == last + 1 { adjacency += 1 }
            last = index
            cursor = index + 1
        }
        return 1_000 + adjacency * 20 - min(last - (first ?? 0), 500) - min(first ?? 0, 200)
    }
}

public enum WorktreeSelection {
    /// Selection stays on the same checkout through refreshes, or falls back to the first result.
    public static func resolved(_ selection: String?, in ids: [String]) -> String? {
        selection.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first
    }

    public static func moved(_ selection: String?, by offset: Int, in ids: [String]) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let selection, let index = ids.firstIndex(of: selection) else {
            return offset < 0 ? ids.last : ids.first
        }
        return ids[max(0, min(ids.count - 1, index + offset))]
    }
}
