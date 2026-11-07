import Foundation
import Testing
@testable import TwigCore

struct WorktreeActivityGroupingTests {
    private let locale = Locale(identifier: "en_US")

    @Test
    func bucketsAreChronologicalAndPreserveInputOrderWithinEach() {
        let calendar = warsawCalendar()
        let now = date(2026, 11, 26, 12, calendar: calendar)
        let rows = [
            worktree("old-year", date: date(2025, 12, 10, calendar: calendar)),
            worktree("last-week-first", date: date(2026, 11, 17, calendar: calendar)),
            worktree("today", date: now),
            worktree("october", date: date(2026, 10, 10, calendar: calendar)),
            worktree("monday", date: date(2026, 11, 23, calendar: calendar)),
            worktree("wednesday", date: date(2026, 11, 25, calendar: calendar)),
            worktree("earlier-month", date: date(2026, 11, 10, calendar: calendar)),
            worktree("last-week-second", date: date(2026, 11, 22, calendar: calendar)),
            worktree("unknown", date: .distantPast),
            worktree("july", date: date(2026, 7, 10, calendar: calendar))
        ]
        let sections = grouped(rows, now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["Today", "Wednesday", "Monday", "Last week", "Earlier this month", "October", "July", "December 2025", "Older"])
        #expect(sections[3].worktrees.map(\.id) == ["last-week-first", "last-week-second"])
        #expect(sections.flatMap(\.worktrees).count == rows.count)
        #expect(Set(sections.map(\.id)).count == sections.count)
        #expect(sections.allSatisfy { !$0.isRepositoryGroup })
    }

    @Test
    func effectiveDatesOverrideObservedDatesAndMissingValuesFallBack() {
        let calendar = warsawCalendar()
        let now = date(2026, 11, 26, 12, calendar: calendar)
        let opened = worktree("opened", date: date(2026, 10, 1, calendar: calendar))
        let observed = worktree("observed", date: date(2026, 11, 25, calendar: calendar))
        let unknown = worktree("unknown", date: now)
        let sections = grouped([observed, unknown, opened], dates: [opened.id: now, unknown.id: .distantPast], now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["Today", "Wednesday", "Older"])
        #expect(sections.flatMap(\.worktrees).map(\.id) == [opened.id, observed.id, unknown.id])
    }

    @Test
    func futureDatesClampToTodayAndUnknownDatesAreLast() {
        let calendar = warsawCalendar()
        let now = date(2026, 11, 26, 12, calendar: calendar)
        let rows = [
            worktree("unknown", date: .distantPast),
            worktree("future", date: date(2030, 1, 1, calendar: calendar)),
            worktree("invalid", date: Date(timeIntervalSince1970: .nan)),
            worktree("today", date: now)
        ]
        let sections = grouped(rows, now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["Today", "Older"])
        #expect(sections[0].worktrees.map(\.id) == ["future", "today"])
        #expect(sections[1].worktrees.map(\.id) == ["unknown", "invalid"])
    }

    @Test
    func pinsOccurOnceBeforeDatedSectionsWithoutEmptyBuckets() {
        let calendar = warsawCalendar()
        let now = date(2026, 11, 26, 12, calendar: calendar)
        let oldPin = worktree("old-pin", date: date(2025, 1, 1, calendar: calendar))
        let newPin = worktree("new-pin", date: now)
        let other = worktree("other", date: date(2026, 11, 25, calendar: calendar))
        let sections = grouped([oldPin, other, newPin, oldPin], pinnedIDs: [oldPin.id, newPin.id], now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["Pinned", "Wednesday"])
        #expect(sections[0].worktrees.map(\.id) == [oldPin.id, newPin.id])
        #expect(sections[1].worktrees.map(\.id) == [other.id])
        let allPinned = grouped([oldPin, newPin], pinnedIDs: [oldPin.id, newPin.id], now: now, calendar: calendar)
        #expect(allPinned.count == 1)
        #expect(allPinned[0].id == "pinned")
        #expect(grouped([], now: now, calendar: calendar).isEmpty)
    }

    @Test
    func todayUsesLocalMidnightInsteadOfElapsedHoursOrUTC() {
        let calendar = warsawCalendar()
        let now = date(2026, 11, 24, 0, 15, calendar: calendar)
        let rows = [
            worktree("previous-day", date: date(2026, 11, 23, 23, 50, calendar: calendar)),
            worktree("today", date: date(2026, 11, 24, 0, 1, calendar: calendar))
        ]
        let sections = grouped(rows, now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["Today", "Monday"])
        #expect(sections[0].worktrees.map(\.id) == ["today"])
    }

    @Test
    func calendarFirstWeekdayControlsLastWeekBoundary() {
        let mondayCalendar = warsawCalendar()
        var sundayCalendar = mondayCalendar
        sundayCalendar.firstWeekday = 1
        let now = date(2026, 11, 23, 12, calendar: mondayCalendar)
        let sunday = worktree("sunday", date: date(2026, 11, 22, 12, calendar: mondayCalendar))
        #expect(grouped([sunday], now: now, calendar: mondayCalendar).map(\.title) == ["Last week"])
        #expect(grouped([sunday], now: now, calendar: sundayCalendar).map(\.title) == ["Sunday"])
    }

    @Test
    func weekBucketsTakePrecedenceAcrossYearBoundaries() {
        let calendar = warsawCalendar()
        let now = date(2027, 1, 2, 12, calendar: calendar)
        let rows = [
            worktree("month", date: date(2026, 12, 20, calendar: calendar)),
            worktree("last-week-end", date: date(2026, 12, 27, 23, 59, calendar: calendar)),
            worktree("this-week-start", date: date(2026, 12, 28, calendar: calendar)),
            worktree("last-year-thursday", date: date(2026, 12, 31, calendar: calendar)),
            worktree("last-week-start", date: date(2026, 12, 21, calendar: calendar)),
            worktree("today", date: now)
        ]
        let sections = grouped(rows, now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["Today", "Thursday", "Monday", "Last week", "December 2026"])
        #expect(sections[3].worktrees.map(\.id) == ["last-week-end", "last-week-start"])
    }

    @Test
    func lastWeekSpanningTwoMonthsIsOneBucket() {
        let calendar = warsawCalendar()
        let now = date(2026, 11, 3, 12, calendar: calendar)
        let rows = [
            worktree("october", date: date(2026, 10, 25, calendar: calendar)),
            worktree("november-last-week", date: date(2026, 11, 1, calendar: calendar)),
            worktree("october-last-week", date: date(2026, 10, 31, calendar: calendar)),
            worktree("this-week", date: date(2026, 11, 2, calendar: calendar))
        ]
        let sections = grouped(rows, now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["Monday", "Last week", "October"])
        #expect(sections[1].worktrees.map(\.id) == ["november-last-week", "october-last-week"])
    }

    @Test
    func daylightSavingDaysUseCalendarBoundaries() throws {
        let calendar = warsawCalendar()
        for (month, day, expectedHours) in [(3, 29, 23), (10, 25, 25)] {
            let now = date(2026, month, day, 23, 30, calendar: calendar)
            let interval = try #require(calendar.dateInterval(of: .day, for: now))
            #expect(interval.duration == Double(expectedHours * 3600))
            let rows = [
                worktree("saturday", date: date(2026, month, day - 1, 23, 45, calendar: calendar)),
                worktree("early-today", date: date(2026, month, day, 0, 15, calendar: calendar))
            ]
            let sections = grouped(rows, now: now, calendar: calendar)
            #expect(sections.map(\.title) == ["Today", "Saturday"])
            #expect(sections[0].worktrees.map(\.id) == ["early-today"])
        }
    }

    @Test
    func localizedTitlesDoNotChangeSectionIdentity() {
        let calendar = warsawCalendar()
        let now = date(2026, 11, 26, 12, calendar: calendar)
        let rows = [
            worktree("wednesday", date: date(2026, 11, 25, calendar: calendar)),
            worktree("october", date: date(2026, 10, 10, calendar: calendar))
        ]
        let english = grouped(rows, now: now, calendar: calendar)
        let polish = WorktreeOrganization.sections(rows, pinnedIDs: [], sortOrder: .activity,
                                                   activityDates: [:], now: now, calendar: calendar,
                                                   locale: Locale(identifier: "pl_PL"))
        #expect(english.map(\.title) == ["Wednesday", "October"])
        #expect(polish.map(\.title) == ["środa", "październik"])
        #expect(polish.map(\.id) == english.map(\.id))
    }

    @Test
    func daySectionKeepsIdentityWhenTodayBecomesAWeekday() {
        let calendar = warsawCalendar()
        let row = worktree("wednesday", date: date(2026, 11, 25, 12, calendar: calendar))
        let before = grouped([row], now: date(2026, 11, 25, 23, 59, calendar: calendar), calendar: calendar)
        let after = grouped([row], now: date(2026, 11, 26, 0, 1, calendar: calendar), calendar: calendar)
        #expect(before.map(\.title) == ["Today"])
        #expect(after.map(\.title) == ["Wednesday"])
        #expect(before.map(\.id) == after.map(\.id))
    }

    @Test
    func projectIgnoresActivityBucketsAndNilDatesKeepSearchFlat() {
        let calendar = warsawCalendar()
        let now = date(2026, 11, 26, 12, calendar: calendar)
        let rows = [
            worktree("older", date: .distantPast, repository: "Website"),
            worktree("today", date: now, repository: "Atlas"),
            worktree("yesterday", date: date(2026, 11, 25, calendar: calendar), repository: "Website")
        ]
        let project = WorktreeOrganization.sections(rows, pinnedIDs: [], sortOrder: .project)
        let datedProject = WorktreeOrganization.sections(rows, pinnedIDs: [], sortOrder: .project,
                                                         activityDates: [:], now: now, calendar: calendar, locale: locale)
        #expect(datedProject == project)
        let search = WorktreeOrganization.sections(rows, pinnedIDs: [], sortOrder: .activity,
                                                   activityDates: nil, now: now, calendar: calendar, locale: locale)
        #expect(search.count == 1)
        #expect(search[0].title == nil)
        #expect(search[0].worktrees.map(\.id) == rows.map(\.id))
    }

    private func grouped(
        _ worktrees: [Worktree], pinnedIDs: Set<String> = [], dates: [String: Date] = [:],
        now: Date, calendar: Calendar
    ) -> [WorktreeSection] {
        WorktreeOrganization.sections(worktrees, pinnedIDs: pinnedIDs, sortOrder: .activity,
                                       activityDates: dates, now: now, calendar: calendar, locale: locale)
    }

    private func warsawCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        calendar.locale = locale
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func worktree(_ id: String, date: Date, repository: String = "Atlas") -> Worktree {
        Worktree(id: id, folder: URL(fileURLWithPath: "/tmp/activity-tests/\(id)"), repositoryName: repository,
                 branch: "feature/\(id)", headRevision: nil, lastActivity: date,
                 commonGitDirectory: URL(fileURLWithPath: "/projects/\(repository)/.git"))
    }
}
