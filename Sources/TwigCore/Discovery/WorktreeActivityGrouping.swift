import Foundation

/// Calendar boundaries are calculated once per presentation, never as rolling
/// hour counts, so midnight, week starts, and daylight saving remain local.
enum WorktreeActivityGrouping {
    static func sections(
        _ worktrees: [Worktree], activityDates: [String: Date], now: Date,
        calendar: Calendar, locale: Locale
    ) -> [WorktreeSection] {
        let context = Context(now: now, calendar: calendar, locale: locale)
        var groups: [Bucket: [Worktree]] = [:]
        for worktree in worktrees {
            let date = activityDates[worktree.id] ?? worktree.lastActivity
            groups[context.bucket(for: date), default: []].append(worktree)
        }
        return groups.sorted {
            $0.key.start == $1.key.start ? $0.key.id < $1.key.id : $0.key.start > $1.key.start
        }.map { bucket, worktrees in
            WorktreeSection(id: bucket.id, title: bucket.title, isRepositoryGroup: false, worktrees: worktrees)
        }
    }

    private struct Bucket: Hashable {
        let id: String
        let title: String
        let start: Date

        init(kind: String, title: String, start: Date) {
            self.id = "activity:\(kind):\(start.timeIntervalSinceReferenceDate)"
            self.title = title
            self.start = start
        }

        static let older = Bucket(kind: "older", title: "Older", start: .distantPast)
    }

    private struct Context {
        let now: Date
        let calendar: Calendar
        let today: Date
        let week: DateInterval?
        let previousWeek: DateInterval?
        let month: DateInterval?
        let weekdayFormatter: DateFormatter
        let monthFormatter: DateFormatter
        let monthYearFormatter: DateFormatter

        init(now: Date, calendar: Calendar, locale: Locale) {
            self.now = now
            self.calendar = calendar
            today = calendar.startOfDay(for: now)
            week = calendar.dateInterval(of: .weekOfYear, for: now)
            previousWeek = week.flatMap { interval in
                calendar.date(byAdding: .day, value: -1, to: interval.start)
                    .flatMap { calendar.dateInterval(of: .weekOfYear, for: $0) }
            }
            month = calendar.dateInterval(of: .month, for: now)
            weekdayFormatter = Self.formatter(calendar: calendar, locale: locale, format: "EEEE")
            monthFormatter = Self.formatter(calendar: calendar, locale: locale, format: "LLLL")
            monthYearFormatter = Self.formatter(calendar: calendar, locale: locale, format: "")
            monthYearFormatter.setLocalizedDateFormatFromTemplate("yMMMM")
        }

        func bucket(for activityDate: Date) -> Bucket {
            guard activityDate.timeIntervalSinceReferenceDate.isFinite, activityDate > .distantPast else {
                return .older
            }
            let date = min(activityDate, now)
            if date >= today {
                return Bucket(kind: "day", title: "Today", start: today)
            }
            if let week, date >= week.start {
                return Bucket(kind: "day", title: weekdayFormatter.string(from: date),
                              start: calendar.startOfDay(for: date))
            }
            if let previousWeek, date >= previousWeek.start, date < previousWeek.end {
                return Bucket(kind: "week", title: "Last week", start: previousWeek.start)
            }
            if let month, date >= month.start {
                return Bucket(kind: "month", title: "Earlier this month", start: month.start)
            }
            guard let pastMonth = calendar.dateInterval(of: .month, for: date) else { return .older }
            let formatter = calendar.isDate(date, equalTo: now, toGranularity: .year)
                ? monthFormatter : monthYearFormatter
            return Bucket(kind: "month", title: formatter.string(from: date), start: pastMonth.start)
        }

        private static func formatter(calendar: Calendar, locale: Locale, format: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = format
            return formatter
        }
    }
}
