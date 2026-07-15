//
//  BudgetStore.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 6/14/26.
//

import Combine
import Foundation
import WidgetKit

@MainActor
final class BudgetStore: ObservableObject {
    @Published private(set) var expenses: [Expense] {
        didSet {
            persistence.saveExpenses(expenses)
            updateWidgetSnapshot()
        }
    }

    @Published var monthWindowMode: SpendingWindowMode {
        didSet {
            persistence.saveMonthWindowMode(monthWindowMode)
            updateWidgetSnapshot()
        }
    }

    @Published var weekWindowMode: SpendingWindowMode {
        didSet {
            persistence.saveWeekWindowMode(weekWindowMode)
            updateWidgetSnapshot()
        }
    }

    private let categorizer: SpendingCategorizing
    private let calculator: BudgetCalculator
    private let persistence: BudgetPersisting
    private let calendar: Calendar
    private let nowProvider: () -> Date
    private let updatesWidgets: Bool

    var storageBackend: BudgetStorageBackend {
        persistence.storageBackend
    }

    init(
        categorizer: SpendingCategorizing? = nil,
        calculator: BudgetCalculator? = nil,
        persistence: BudgetPersisting? = nil,
        calendar: Calendar = .current,
        updatesWidgets: Bool = true,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.categorizer = categorizer ?? AppleIntelligenceSpendingCategorizer()
        self.calculator = calculator ?? BudgetCalculator()
        self.persistence = persistence ?? BudgetPersistenceFactory.makeDefault()
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.updatesWidgets = updatesWidgets
        self.expenses = self.persistence.loadExpenses().sorted { $0.date > $1.date }

        self.monthWindowMode = self.persistence.loadMonthWindowMode() ?? .sliding
        self.weekWindowMode = self.persistence.loadWeekWindowMode() ?? .sliding
        materializeRecurringExpenses()
        updateWidgetSnapshot()
    }

    var pendingCategorizationCount: Int {
        expenses.filter { $0.categorizationState == .pending }.count
    }

    @discardableResult
    func addExpense(amount: Decimal, note: String, date: Date? = nil, recurrence: RecurrenceFrequency? = nil, source: ExpenseSource? = nil) -> Expense {
        let expenseDate = date ?? nowProvider()
        let expense = Expense(
            amount: amount,
            note: note,
            date: expenseDate,
            category: .awkward,
            categorizationState: .pending,
            recurrence: recurrence,
            nextOccurrenceDate: recurrence.map { $0.nextDate(after: expenseDate, calendar: calendar) },
            source: source
        )

        expenses.insert(expense, at: 0)
        categorizeInBackground(expense)
        return expense
    }

    /// Records an expense coming from a Shortcuts automation, skipping it when
    /// the same purchase was already captured through another channel — e.g.
    /// an Apple Pay tap logged by the Wallet trigger and then again by the
    /// bank's push notification, or a purchase the user had logged by hand.
    @discardableResult
    func recordAutoCapturedExpense(amount: Decimal, merchant: String, source: ExpenseSource) -> AutoCaptureResult {
        let now = nowProvider()

        if let existing = expenses.first(where: { candidate in
            candidate.amount == amount
                && candidate.recurrence == nil
                && abs(candidate.date.timeIntervalSince(now)) <= Self.autoCaptureDuplicateWindow
        }) {
            // A structured merchant name beats a placeholder note left by an
            // earlier capture that couldn't identify the merchant.
            if existing.note.isEmpty || existing.note == "Expense",
               let index = expenses.firstIndex(where: { $0.id == existing.id }) {
                expenses[index].note = merchant
                categorizeInBackground(expenses[index])
                return AutoCaptureResult(expense: expenses[index], isDuplicate: true)
            }
            return AutoCaptureResult(expense: existing, isDuplicate: true)
        }

        let expense = addExpense(amount: amount, note: merchant, source: source)
        return AutoCaptureResult(expense: expense, isDuplicate: false)
    }

    /// Bank pushes can lag an Apple Pay tap by a couple of minutes.
    static let autoCaptureDuplicateWindow: TimeInterval = 5 * 60

    /// Whether any expense in the ledger arrived through an automation. Also
    /// covers automations set up on another device, since expenses sync.
    var hasAutoCapturedExpenses: Bool {
        expenses.contains { $0.isAutoCaptured }
    }

    struct AutoCaptureResult {
        let expense: Expense
        let isDuplicate: Bool
    }

    func removeExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
    }

    func reloadPersistedData() {
        expenses = persistence.loadExpenses().sorted { $0.date > $1.date }
        monthWindowMode = persistence.loadMonthWindowMode() ?? monthWindowMode
        weekWindowMode = persistence.loadWeekWindowMode() ?? weekWindowMode
        materializeRecurringExpenses()
    }

    func materializeRecurringExpenses() {
        let now = nowProvider()
        var updated = expenses
        var generated: [Expense] = []
        var pendingCategorization: [Expense] = []

        for index in updated.indices where updated[index].recurrence != nil {
            guard let frequency = updated[index].recurrence else {
                continue
            }

            let template = updated[index]
            var nextDue = template.nextOccurrenceDate ?? frequency.nextDate(after: template.date, calendar: calendar)
            var safetyLimit = 400

            while nextDue <= now, safetyLimit > 0 {
                let instance = Expense(
                    amount: template.amount,
                    note: template.note,
                    date: nextDue,
                    category: template.category,
                    categorizationState: template.categorizationState == .categorized ? .categorized : .pending,
                    recurringSourceID: template.id
                )

                generated.append(instance)

                if instance.categorizationState == .pending {
                    pendingCategorization.append(instance)
                }

                let following = frequency.nextDate(after: nextDue, calendar: calendar)
                guard following > nextDue else {
                    break
                }

                nextDue = following
                safetyLimit -= 1
            }

            updated[index].nextOccurrenceDate = nextDue
        }

        guard !generated.isEmpty || updated != expenses else {
            return
        }

        expenses = (updated + generated).sorted { $0.date > $1.date }
        pendingCategorization.forEach(categorizeInBackground)
    }

    func total(for period: BudgetPeriod) -> Decimal {
        calculator.total(
            for: expenses,
            period: period,
            mode: mode(for: period),
            now: nowProvider()
        )
    }

    func categoryTotals(for period: BudgetPeriod) -> [SpendingCategory: Decimal] {
        calculator.categoryTotals(
            for: expenses,
            period: period,
            mode: mode(for: period),
            now: nowProvider()
        )
    }

    func expenses(for period: BudgetPeriod) -> [Expense] {
        calculator.expenses(
            for: expenses,
            period: period,
            mode: mode(for: period),
            now: nowProvider()
        )
    }

    func comparison(for period: BudgetPeriod) -> SpendingComparison {
        calculator.comparison(
            for: expenses,
            period: period,
            mode: mode(for: period),
            now: nowProvider()
        )
    }

    /// Recent spend trend for sparklines, oldest bucket first.
    func trend(for period: BudgetPeriod, buckets: Int = 10) -> [Double] {
        calculator.trailingTotals(
            for: expenses,
            period: period,
            now: nowProvider(),
            bucketCount: buckets
        )
        .map { NSDecimalNumber(decimal: $0).doubleValue }
    }

    func subtitle(for period: BudgetPeriod) -> String {
        calculator.subtitle(
            for: period,
            mode: mode(for: period),
            now: nowProvider()
        )
    }

    private func mode(for period: BudgetPeriod) -> SpendingWindowMode {
        switch period {
        case .day:
            return .calendar
        case .week:
            return weekWindowMode
        case .month:
            return monthWindowMode
        }
    }

    private func categorizeInBackground(_ expense: Expense) {
        Task {
            do {
                let category = try await categorizer.categorize(description: expense.note, amount: expense.amount)
                markExpense(expense.id, category: category, state: .categorized)
            } catch {
                markExpense(expense.id, category: .awkward, state: .needsReview)
            }
        }
    }

    private func markExpense(_ id: UUID, category: SpendingCategory, state: CategorizationState) {
        guard let index = expenses.firstIndex(where: { $0.id == id }) else {
            return
        }

        expenses[index].category = category
        expenses[index].categorizationState = state
    }

    private func updateWidgetSnapshot() {
        guard updatesWidgets else {
            return
        }

        BudgetWidgetDataStore.saveSnapshot(
            expenses: expenses,
            monthWindowMode: monthWindowMode,
            weekWindowMode: weekWindowMode,
            now: nowProvider()
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension BudgetStore {
    static var preview: BudgetStore {
        let now = Date()
        let store = BudgetStore(
            persistence: PreviewExpenseStore(),
            updatesWidgets: false,
            nowProvider: { now }
        )

        store.expenses = [
            Expense(amount: 23.40, note: "Coffee and team breakfast", date: now.addingTimeInterval(-1_800), category: .foodAndDrink, categorizationState: .categorized),
            Expense(amount: 84.12, note: "Groceries at the market", date: now.addingTimeInterval(-26_000), category: .groceries, categorizationState: .categorized),
            Expense(amount: 13.70, note: "Lyft back from office", date: now.addingTimeInterval(-90_000), category: .transport, categorizationState: .categorized),
            Expense(amount: 39.99, note: "Streaming renewal", date: now.addingTimeInterval(-420_000), category: .subscriptions, categorizationState: .categorized)
        ]

        return store
    }
}

/// In-memory persistence so preview/UI-test runs survive `reloadPersistedData()`.
private final class PreviewExpenseStore: BudgetPersisting {
    private var expenses: [Expense] = []
    private var monthWindowMode: SpendingWindowMode = .sliding
    private var weekWindowMode: SpendingWindowMode = .sliding

    var storageBackend: BudgetStorageBackend {
        .preview
    }

    func loadExpenses() -> [Expense] { expenses }
    func saveExpenses(_ expenses: [Expense]) { self.expenses = expenses }
    func loadMonthWindowMode() -> SpendingWindowMode? { monthWindowMode }
    func saveMonthWindowMode(_ mode: SpendingWindowMode) { monthWindowMode = mode }
    func loadWeekWindowMode() -> SpendingWindowMode? { weekWindowMode }
    func saveWeekWindowMode(_ mode: SpendingWindowMode) { weekWindowMode = mode }
}
