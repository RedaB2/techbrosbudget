//
//  VaultLedger.swift
//  techbrosbudget
//
//  Derives the Vault's minted feats and logging stats from the expense
//  history. Pure and deterministic — inject a calendar and "now" to test.
//

import Foundation

/// One slab on the vault shelf: a feat that has been minted, or the next
/// target still shown as an outline.
struct VaultFeat: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let isMinted: Bool
    /// Slab height in points; rarer feats stand taller.
    let height: CGFloat
}

struct VaultLedger: Equatable {
    struct Milestone: Equatable {
        let count: Int
        let title: String
        let height: CGFloat
    }

    /// Lifetime logged-expense counts that mint a slab, named as funding rounds.
    static let expenseMilestones: [Milestone] = [
        Milestone(count: 1, title: "Genesis", height: 64),
        Milestone(count: 10, title: "Pre-seed", height: 74),
        Milestone(count: 25, title: "Seed", height: 84),
        Milestone(count: 100, title: "Series A", height: 98),
        Milestone(count: 250, title: "Series B", height: 110),
        Milestone(count: 1_000, title: "Unicorn", height: 124),
    ]

    static let perfectWeekSlabHeight: CGFloat = 64

    let totalLogged: Int
    let daysRecorded: Int
    let perfectWeekCount: Int
    /// Whether each day of the current week (ordered from the calendar's first
    /// weekday) has at least one logged expense. Always 7 entries.
    let currentWeekDayFlags: [Bool]
    /// Shelf contents: minted feats in the order they were earned, then the
    /// next unearned milestone and the in-progress week as outlines.
    let feats: [VaultFeat]
    let nextMilestone: Milestone?

    var currentWeekDaysRecorded: Int {
        currentWeekDayFlags.filter { $0 }.count
    }

    init(expenses: [Expense], calendar: Calendar = .current, now: Date = Date()) {
        let ascending = expenses.sorted { $0.date < $1.date }
        totalLogged = ascending.count

        let dayStarts = Set(ascending.map { calendar.startOfDay(for: $0.date) })
        daysRecorded = dayStarts.count

        // Minted feats carry the date they were earned so the shelf can stay
        // chronological across feat types.
        var minted: [(date: Date, feat: VaultFeat)] = []

        for milestone in Self.expenseMilestones where totalLogged >= milestone.count {
            let earnedDate = ascending[milestone.count - 1].date
            minted.append((
                date: earnedDate,
                feat: VaultFeat(
                    id: "milestone-\(milestone.count)",
                    title: milestone.title,
                    detail: Self.milestoneDetail(count: milestone.count, earnedDate: earnedDate),
                    isMinted: true,
                    height: milestone.height
                )
            ))
        }

        // Perfect weeks: completed calendar weeks where all seven days have at
        // least one logged expense.
        var perfectWeeks = 0
        let weekStarts = Set(dayStarts.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start })

        for weekStart in weekStarts.sorted() {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: weekStart), week.end <= now else {
                continue
            }

            let daysInWeek = dayStarts.filter { week.contains($0) }.count
            guard daysInWeek >= 7 else {
                continue
            }

            perfectWeeks += 1
            let weekExpenseCount = ascending.filter { week.contains($0.date) }.count
            minted.append((
                date: week.end,
                feat: VaultFeat(
                    id: "week-\(Int(weekStart.timeIntervalSinceReferenceDate))",
                    title: "Perfect week",
                    detail: "\(Self.weekRangeText(for: week, calendar: calendar)) · \(weekExpenseCount) logged · every day recorded",
                    isMinted: true,
                    height: Self.perfectWeekSlabHeight
                )
            ))
        }

        perfectWeekCount = perfectWeeks

        // Current week progress, ordered from the calendar's first weekday.
        var dayFlags: [Bool] = []
        if let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now) {
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: currentWeek.start) else {
                    dayFlags.append(false)
                    continue
                }

                dayFlags.append(dayStarts.contains(calendar.startOfDay(for: day)))
            }
        } else {
            dayFlags = Array(repeating: false, count: 7)
        }
        currentWeekDayFlags = dayFlags

        let next = Self.expenseMilestones.first { $0.count > ascending.count }
        nextMilestone = next

        var shelf = minted.sorted { $0.date < $1.date }.map(\.feat)

        if let next {
            let remaining = next.count - ascending.count
            shelf.append(
                VaultFeat(
                    id: "milestone-\(next.count)",
                    title: next.title,
                    detail: "Mints at \(next.count) logged · \(remaining) to go",
                    isMinted: false,
                    height: next.height
                )
            )
        }

        let daysSoFar = dayFlags.filter { $0 }.count
        shelf.append(
            VaultFeat(
                id: "week-current",
                title: "Perfect week",
                detail: daysSoFar >= 7
                    ? "Every day recorded — mints when the week closes"
                    : "\(daysSoFar) of 7 days recorded — mints if the week holds",
                isMinted: false,
                height: Self.perfectWeekSlabHeight
            )
        )

        feats = shelf
    }

    /// The feat whose plaque shows by default: the most recently minted slab.
    var latestMintedFeat: VaultFeat? {
        feats.last { $0.isMinted }
    }

    private static func milestoneDetail(count: Int, earnedDate: Date) -> String {
        let day = earnedDate.formatted(.dateTime.month(.abbreviated).day())

        if count == 1 {
            return "The first expense ever logged · \(day)"
        }

        return "Logged expense № \(count) · \(day)"
    }

    private static func weekRangeText(for week: DateInterval, calendar: Calendar) -> String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.end
        let start = week.start.formatted(.dateTime.month(.abbreviated).day())

        let sameMonth = calendar.isDate(week.start, equalTo: lastDay, toGranularity: .month)
        let end = sameMonth
            ? lastDay.formatted(.dateTime.day())
            : lastDay.formatted(.dateTime.month(.abbreviated).day())

        return "\(start) – \(end)"
    }
}
