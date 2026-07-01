//
//  BudgetWidgetDataStore.swift
//  techbrosbudget
//
//  Created by OpenAI on 6/28/26.
//

import Foundation

struct BudgetWidgetSnapshot: Codable, Equatable {
    let generatedAt: Date
    let totals: [BudgetWidgetPeriodTotal]

    func total(for period: BudgetPeriod) -> BudgetWidgetPeriodTotal {
        totals.first { $0.period == period } ?? .empty(period: period)
    }

    static func make(
        expenses: [Expense],
        monthWindowMode: SpendingWindowMode,
        weekWindowMode: SpendingWindowMode,
        now: Date = Date(),
        calculator: BudgetCalculator = BudgetCalculator()
    ) -> BudgetWidgetSnapshot {
        let totals = [BudgetPeriod.month, .week, .day].map { period in
            BudgetWidgetPeriodTotal(
                period: period,
                amount: calculator.total(
                    for: expenses,
                    period: period,
                    mode: mode(for: period, monthWindowMode: monthWindowMode, weekWindowMode: weekWindowMode),
                    now: now
                ),
                subtitle: calculator.subtitle(
                    for: period,
                    mode: mode(for: period, monthWindowMode: monthWindowMode, weekWindowMode: weekWindowMode),
                    now: now
                )
            )
        }

        return BudgetWidgetSnapshot(generatedAt: now, totals: totals)
    }

    static func empty(now: Date = Date()) -> BudgetWidgetSnapshot {
        BudgetWidgetSnapshot(
            generatedAt: now,
            totals: [BudgetPeriod.month, .week, .day].map { .empty(period: $0) }
        )
    }

    private static func mode(
        for period: BudgetPeriod,
        monthWindowMode: SpendingWindowMode,
        weekWindowMode: SpendingWindowMode
    ) -> SpendingWindowMode {
        switch period {
        case .day:
            return .calendar
        case .week:
            return weekWindowMode
        case .month:
            return monthWindowMode
        }
    }
}

struct BudgetWidgetPeriodTotal: Codable, Equatable, Identifiable {
    let period: BudgetPeriod
    let amount: Decimal
    let subtitle: String

    var id: BudgetPeriod { period }

    static func empty(period: BudgetPeriod) -> BudgetWidgetPeriodTotal {
        BudgetWidgetPeriodTotal(
            period: period,
            amount: .zero,
            subtitle: period == .day ? "Calendar day" : "No spending logged"
        )
    }
}

enum BudgetWidgetDataStore {
    static let appGroupIdentifier = "group.reda.techbrosbudget"

    private static let snapshotKey = "techbrosbudget.widget.snapshot"

    static func saveSnapshot(
        expenses: [Expense],
        monthWindowMode: SpendingWindowMode,
        weekWindowMode: SpendingWindowMode,
        now: Date = Date()
    ) {
        let snapshot = BudgetWidgetSnapshot.make(
            expenses: expenses,
            monthWindowMode: monthWindowMode,
            weekWindowMode: weekWindowMode,
            now: now
        )

        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        sharedDefaults?.set(data, forKey: snapshotKey)
        UserDefaults.standard.set(data, forKey: snapshotKey)
    }

    static func loadSnapshot(now: Date = Date()) -> BudgetWidgetSnapshot {
        guard let data = sharedDefaults?.data(forKey: snapshotKey)
            ?? UserDefaults.standard.data(forKey: snapshotKey)
        else {
            return .empty(now: now)
        }

        return (try? JSONDecoder().decode(BudgetWidgetSnapshot.self, from: data)) ?? .empty(now: now)
    }

    static func previewSnapshot(now: Date = Date()) -> BudgetWidgetSnapshot {
        BudgetWidgetSnapshot.make(
            expenses: [
                Expense(amount: 384.21, note: "Groceries", date: now.addingTimeInterval(-2_800), category: .groceries, categorizationState: .categorized),
                Expense(amount: 92.40, note: "Rideshare", date: now.addingTimeInterval(-43_000), category: .transport, categorizationState: .categorized),
                Expense(amount: 64.99, note: "Streaming", date: now.addingTimeInterval(-210_000), category: .subscriptions, categorizationState: .categorized),
                Expense(amount: 18.60, note: "Coffee", date: now.addingTimeInterval(-760), category: .foodAndDrink, categorizationState: .categorized)
            ],
            monthWindowMode: .sliding,
            weekWindowMode: .sliding,
            now: now
        )
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
}
