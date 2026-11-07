import Foundation
import Testing
@testable import TwigCore

struct WorktreeSearchTests {
    @Test func contiguousNamesRankAheadOfFuzzyPaths() throws {
        let exact = try #require(WorktreeSearch.score(query: "login", fields: ["login"]))
        let prefix = try #require(WorktreeSearch.score(query: "login", fields: ["login-redesign"]))
        let word = try #require(WorktreeSearch.score(query: "login", fields: ["feature/login"]))
        let fuzzy = try #require(WorktreeSearch.score(query: "login", fields: ["long-going-intro"]))
        #expect(exact > prefix)
        #expect(prefix > word)
        #expect(word > fuzzy)
    }

    @Test func everyTokenMustMatchButMayUseDifferentFields() {
        let fields = ["Atlas", "feature/keyboard-navigation", "Xcode"]
        #expect(WorktreeSearch.score(query: "atl keynav xc", fields: fields) != nil)
        #expect(WorktreeSearch.score(query: "atl missing", fields: fields) == nil)
        #expect(WorktreeSearch.score(query: "", fields: []) == 0)
        #expect(WorktreeSearch.score(query: "   \n", fields: fields) == 0)
    }

    @Test func searchFoldsAccentsAndHandlesRepeatedCharacters() {
        #expect(WorktreeSearch.score(query: "cafe", fields: ["CAFÉ"]) == 10_000)
        #expect(WorktreeSearch.score(query: "abc", fields: ["acb"]) == nil)
        #expect(WorktreeSearch.score(query: "aaa", fields: ["aa"]) == nil)
        #expect(WorktreeSearch.score(query: "a", fields: [""]) == nil)
        #expect(WorktreeSearch.score(query: "💡", fields: ["fix/💡"]) != nil)
    }

    @Test func absolutePathsDoNotCreateUnrelatedFuzzyResults() {
        let path = "/Users/atlas/.codex/worktrees/search-fixtures/Website"
        #expect(WorktreeSearch.score(query: "at srch", fields: ["Website", "refresh/landing", "Xcode"],
                                    literalFields: [path]) == nil)
        #expect(WorktreeSearch.score(query: "at srch", fields: ["Atlas", "Instant search", "feature/search"],
                                    literalFields: [path]) != nil)
        #expect(WorktreeSearch.score(query: "search-fixtures", fields: ["Website"],
                                    literalFields: [path]) != nil)
        #expect(WorktreeSearch.score(query: "/users/ATLAS", fields: ["Website"],
                                    literalFields: [path]) != nil)
    }

    @Test func selectionSurvivesReorderingAndFallsBackWhenRemoved() {
        #expect(WorktreeSelection.resolved("b", in: ["c", "b", "a"]) == "b")
        #expect(WorktreeSelection.resolved("b", in: ["c", "a"]) == "c")
        #expect(WorktreeSelection.resolved("b", in: []) == nil)
        #expect(WorktreeSelection.moved("b", by: 1, in: ["a", "b", "c"]) == "c")
        #expect(WorktreeSelection.moved("c", by: 1, in: ["a", "b", "c"]) == "c")
        #expect(WorktreeSelection.moved("a", by: -1, in: ["a", "b", "c"]) == "a")
        #expect(WorktreeSelection.moved(nil, by: -1, in: ["a", "b"]) == "b")
        #expect(WorktreeSelection.moved("a", by: 1, in: []) == nil)
    }

    @Test func previousUsesSuccessfulOpensAndSkipsMissingCheckouts() {
        var preferences = TwigPreferences(lastOpened: ["a": Date(timeIntervalSince1970: 10),
            "b": Date(timeIntervalSince1970: 20), "removed": Date(timeIntervalSince1970: 30)])
        #expect(preferences.previousWorktreeID(among: ["a", "b"]) == "a")
        preferences.lastOpened["a"] = Date(timeIntervalSince1970: 40)
        #expect(preferences.previousWorktreeID(among: ["a", "b"]) == "b")
        #expect(preferences.previousWorktreeID(among: ["a"]) == "a")
        #expect(preferences.previousWorktreeID(among: []) == nil)
    }

    @Test func shortcutMigrationAndDisabledStateRoundTrip() throws {
        let old = try JSONDecoder().decode(TwigPreferences.self, from: Data("{\"schemaVersion\":1}".utf8))
        #expect(old.globalShortcut == .default)
        var preferences = TwigPreferences(globalShortcut: nil)
        var decoded = try JSONDecoder().decode(TwigPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded.globalShortcut == nil)
        preferences.globalShortcut = GlobalShortcut(keyCode: 17, modifiers: [.control, .shift], keyLabel: "T")
        decoded = try JSONDecoder().decode(TwigPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded.globalShortcut == preferences.globalShortcut)
        #expect(decoded.globalShortcut?.displayName == "⌃⇧T")
        #expect(GlobalShortcut.default.isValid)
        #expect(!GlobalShortcut(keyCode: 17, modifiers: [.shift], keyLabel: "T").isValid)
        #expect(!GlobalShortcut(keyCode: 500, modifiers: [.control], keyLabel: "T").isValid)
    }
}
