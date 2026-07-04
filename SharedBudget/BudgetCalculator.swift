//
//  BudgetCalculator.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 6/14/26.
//

import Foundation

struct BudgetCalculator {
    var calendar: Calendar = .current

    func interval(for period: BudgetPeriod, mode: SpendingWindowMode, now: Date) -> DateInterval {
        switch period {
        case .day:
            return calendar.dateInterval(of: .day, for: now) ?? fallbackInterval(days: 1, endingAt: now)
        case .week:
            switch mode {
            case .sliding:
                return fallbackInterval(days: 7, endingAt: now)
            case .calendar:
                return calendar.dateInterval(of: .weekOfYear, for: now) ?? fallbackInterval(days: 7, endingAt: now)
            }
        case .month:
            switch mode {
            case .sliding:
                return fallbackInterval(days: 30, endingAt: now)
            case .calendar:
                return calendar.dateInterval(of: .month, for: now) ?? fallbackInterval(days: 30, endingAt: now)
            }
        }
    }

    func previousInterval(for period: BudgetPeriod, mode: SpendingWindowMode, now: Date) -> DateInterval {
        let currentInterval = interval(for: period, mode: mode, now: now)

        switch period {
        case .day:
            return calendar.dateInterval(of: .day, for: currentInterval.start.addingTimeInterval(-1))
                ?? fallbackInterval(days: 1, endingAt: currentInterval.start)
        case .week:
            switch mode {
            case .sliding:
                return previousSlidingInterval(matching: currentInterval)
            case .calendar:
                return calendar.dateInterval(of: .weekOfYear, for: currentInterval.start.addingTimeInterval(-1))
                    ?? previousSlidingInterval(matching: currentInterval)
            }
        case .month:
            switch mode {
            case .sliding:
                return previousSlidingInterval(matching: currentInterval)
            case .calendar:
                return calendar.dateInterval(of: .month, for: currentInterval.start.addingTimeInterval(-1))
                    ?? previousSlidingInterval(matching: currentInterval)
            }
        }
    }

    func total(
        for expenses: [Expense],
        period: BudgetPeriod,
        mode: SpendingWindowMode,
        now: Date
    ) -> Decimal {
        let interval = interval(for: period, mode: mode, now: now)
        return total(for: expenses, in: interval)
    }

    func total(for expenses: [Expense], in interval: DateInterval) -> Decimal {
        return expenses.reduce(Decimal.zero) { partialResult, expense in
            contains(expense.date, in: interval) ? partialResult + expense.amount : partialResult
        }
    }

    func expenses(
        for expenses: [Expense],
        period: BudgetPeriod,
        mode: SpendingWindowMode,
        now: Date
    ) -> [Expense] {
        let interval = interval(for: period, mode: mode, now: now)

        return expenses
            .filter { contains($0.date, in: interval) }
            .sorted { $0.date > $1.date }
    }

    func categoryTotals(
        for expenses: [Expense],
        period: BudgetPeriod,
        mode: SpendingWindowMode,
        now: Date
    ) -> [SpendingCategory: Decimal] {
        let interval = interval(for: period, mode: mode, now: now)

        return expenses.reduce(into: [SpendingCategory: Decimal]()) { result, expense in
            guard contains(expense.date, in: interval) else {
                return
            }

            result[expense.category, default: .zero] += expense.amount
        }
    }

    func comparison(
        for expenses: [Expense],
        period: BudgetPeriod,
        mode: SpendingWindowMode,
        now: Date
    ) -> SpendingComparison {
        let currentInterval = interval(for: period, mode: mode, now: now)
        let previousInterval = previousInterval(for: period, mode: mode, now: now)
        let currentTotal = total(for: expenses, in: currentInterval)
        let previousTotal = total(for: expenses, in: previousInterval)

        return SpendingComparison(
            currentTotal: currentTotal,
            previousTotal: previousTotal,
            percentChange: percentChange(current: currentTotal, previous: previousTotal),
            previousLabel: previousLabel(for: period, mode: mode)
        )
    }

    /// Totals for the last `bucketCount` back-to-back windows of the period's
    /// nominal length, ending at `now`, oldest first. Drives trend sparklines.
    func trailingTotals(
        for expenses: [Expense],
        period: BudgetPeriod,
        now: Date,
        bucketCount: Int
    ) -> [Decimal] {
        let bucketLength: TimeInterval
        switch period {
        case .day:
            bucketLength = 86_400
        case .week:
            bucketLength = 7 * 86_400
        case .month:
            bucketLength = 30 * 86_400
        }

        var totals: [Decimal] = []
        var end = now

        for _ in 0..<max(0, bucketCount) {
            let start = end.addingTimeInterval(-bucketLength)
            totals.append(total(for: expenses, in: DateInterval(start: start, end: end)))
            end = start
        }

        return totals.reversed()
    }

    func subtitle(for period: BudgetPeriod, mode: SpendingWindowMode, now: Date) -> String {
        let interval = interval(for: period, mode: mode, now: now)

        switch period {
        case .day:
            return "Calendar day"
        case .week:
            return mode == .sliding ? "Last 7 days" : dateRange(interval)
        case .month:
            return mode == .sliding ? "Last 30 days" : dateRange(interval)
        }
    }

    private func fallbackInterval(days: Int, endingAt end: Date) -> DateInterval {
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? end.addingTimeInterval(TimeInterval(-days * 86_400))
        return DateInterval(start: start, end: end)
    }

    private func previousSlidingInterval(matching currentInterval: DateInterval) -> DateInterval {
        let duration = currentInterval.duration
        return DateInterval(start: currentInterval.start.addingTimeInterval(-duration), end: currentInterval.start)
    }

    private func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }

    private func percentChange(current: Decimal, previous: Decimal) -> Decimal {
        guard previous != 0 else {
            return current == 0 ? 0 : current
        }

        return ((current - previous) / previous) * 100
    }

    private func previousLabel(for period: BudgetPeriod, mode: SpendingWindowMode) -> String {
        switch period {
        case .day:
            return "yesterday"
        case .week:
            return mode == .sliding ? "previous 7 days" : "last week"
        case .month:
            return mode == .sliding ? "previous 30 days" : "last month"
        }
    }

    private func dateRange(_ interval: DateInterval) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: interval.start, to: interval.end.addingTimeInterval(-1))
    }
}
