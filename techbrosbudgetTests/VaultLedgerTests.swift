//
//  VaultLedgerTests.swift
//  techbrosbudgetTests
//

import Foundation
import Testing
@testable import techbrosbudget

struct VaultLedgerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    /// Monday 2026-06-01 00:00 UTC.
    private var weekStart: Date {
        Date(timeIntervalSince1970: 1_780_272_000)
    }

    private func expense(daysAfterStart days: Int, hour: Int = 12) -> Expense {
        Expense(
            amount: 10,
            note: "expense",
            date: weekStart.addingTimeInterval(TimeInterval(days * 86_400 + hour * 3_600)),
            category: .foodAndDrink
        )
    }

    @Test func emptyHistoryMintsNothingAndTargetsGenesis() {
        let ledger = VaultLedger(expenses: [], calendar: calendar, now: weekStart)

        #expect(ledger.totalLogged == 0)
        #expect(ledger.daysRecorded == 0)
        #expect(ledger.perfectWeekCount == 0)
        #expect(ledger.feats.allSatisfy { !$0.isMinted })
        #expect(ledger.nextMilestone?.count == 1)
        #expect(ledger.latestMintedFeat == nil)
    }

    @Test func firstExpenseMintsGenesis() {
        let now = weekStart.addingTimeInterval(2 * 86_400)
        let ledger = VaultLedger(expenses: [expense(daysAfterStart: 0)], calendar: calendar, now: now)

        #expect(ledger.totalLogged == 1)
        #expect(ledger.latestMintedFeat?.title == "Genesis")
        #expect(ledger.nextMilestone?.count == 10)
    }

    @Test func sevenLoggedDaysInAClosedWeekMintAPerfectWeek() {
        let expenses = (0..<7).map { expense(daysAfterStart: $0) }
        let nextMonday = weekStart.addingTimeInterval(7 * 86_400)
        let ledger = VaultLedger(expenses: expenses, calendar: calendar, now: nextMonday)

        #expect(ledger.perfectWeekCount == 1)
        #expect(ledger.feats.contains { $0.title == "Perfect week" && $0.isMinted })
    }

    @Test func openWeekDoesNotMintEvenWithSevenDays() {
        let expenses = (0..<7).map { expense(daysAfterStart: $0) }
        // "Now" is still Sunday of the same week.
        let sunday = weekStart.addingTimeInterval(6 * 86_400 + 20 * 3_600)
        let ledger = VaultLedger(expenses: expenses, calendar: calendar, now: sunday)

        #expect(ledger.perfectWeekCount == 0)
        #expect(ledger.currentWeekDaysRecorded == 7)
    }

    @Test func weekWithAGapDoesNotMint() {
        let expenses = [0, 1, 2, 4, 5, 6].map { expense(daysAfterStart: $0) }
        let nextMonday = weekStart.addingTimeInterval(7 * 86_400)
        let ledger = VaultLedger(expenses: expenses, calendar: calendar, now: nextMonday)

        #expect(ledger.perfectWeekCount == 0)
        #expect(ledger.daysRecorded == 6)
    }

    @Test func currentWeekFlagsFollowTheCalendarsFirstWeekday() {
        // Logs on Monday and Wednesday of the current week.
        let expenses = [expense(daysAfterStart: 0), expense(daysAfterStart: 2)]
        let thursday = weekStart.addingTimeInterval(3 * 86_400)
        let ledger = VaultLedger(expenses: expenses, calendar: calendar, now: thursday)

        #expect(ledger.currentWeekDayFlags == [true, false, true, false, false, false, false])
    }

    @Test func milestonesMintInOrderWithEarnedDates() {
        // 10 expenses across two days.
        let expenses = (0..<10).map { expense(daysAfterStart: $0 / 5, hour: 6 + $0 % 5) }
        let ledger = VaultLedger(expenses: expenses, calendar: calendar, now: weekStart.addingTimeInterval(3 * 86_400))

        let mintedTitles = ledger.feats.filter(\.isMinted).map(\.title)
        #expect(mintedTitles == ["Genesis", "Pre-seed"])
        #expect(ledger.nextMilestone?.count == 25)

        // The unearned outline for Seed plus the in-progress week follow.
        let outlines = ledger.feats.filter { !$0.isMinted }.map(\.title)
        #expect(outlines == ["Seed", "Perfect week"])
    }

    @Test func multipleDistinctPerfectWeeksEachMint() {
        let weekOne = (0..<7).map { expense(daysAfterStart: $0) }
        let weekThree = (14..<21).map { expense(daysAfterStart: $0) }
        let afterWeekThree = weekStart.addingTimeInterval(22 * 86_400)
        let ledger = VaultLedger(expenses: weekOne + weekThree, calendar: calendar, now: afterWeekThree)

        #expect(ledger.perfectWeekCount == 2)
        #expect(ledger.totalLogged == 14)
        #expect(ledger.feats.filter { $0.title == "Perfect week" && $0.isMinted }.count == 2)
    }
}
