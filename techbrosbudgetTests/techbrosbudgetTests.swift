//
//  techbrosbudgetTests.swift
//  techbrosbudgetTests
//
//  Created by Reda Boutayeb on 6/14/26.
//

import Foundation
import Testing
@testable import techbrosbudget

struct techbrosbudgetTests {
    @Test func slidingWindowsTotalRecentSpendingOnly() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let calculator = BudgetCalculator(calendar: Calendar(identifier: .gregorian))
        let expenses = [
            Expense(amount: 10, note: "coffee", date: now.addingTimeInterval(-60), category: .foodAndDrink),
            Expense(amount: 20, note: "taxi", date: now.addingTimeInterval(-6 * 86_400), category: .transport),
            Expense(amount: 30, note: "old lunch", date: now.addingTimeInterval(-8 * 86_400), category: .foodAndDrink),
            Expense(amount: 40, note: "old bill", date: now.addingTimeInterval(-31 * 86_400), category: .utilities)
        ]

        #expect(calculator.total(for: expenses, period: .week, mode: .sliding, now: now) == 30)
        #expect(calculator.total(for: expenses, period: .month, mode: .sliding, now: now) == 60)
    }

    @Test func calendarWindowsUseCalendarBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2

        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 14, hour: 12)))
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let previousSunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 23)))
        let firstOfMonth = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))
        let previousMonth = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 23)))

        let calculator = BudgetCalculator(calendar: calendar)
        let expenses = [
            Expense(amount: 10, note: "weekly", date: monday, category: .foodAndDrink),
            Expense(amount: 20, note: "previous week", date: previousSunday, category: .transport),
            Expense(amount: 30, note: "monthly", date: firstOfMonth, category: .groceries),
            Expense(amount: 40, note: "previous month", date: previousMonth, category: .utilities)
        ]

        #expect(calculator.total(for: expenses, period: .week, mode: .calendar, now: now) == 10)
        #expect(calculator.total(for: expenses, period: .month, mode: .calendar, now: now) == 60)
    }

    @Test func categorizerUsesAgreedGeneralCategoriesAndAwkwardFallback() {
        #expect(LocalHeuristicSpendingCategorizer.category(for: "Uber to airport") == .transport)
        #expect(LocalHeuristicSpendingCategorizer.category(for: "team lunch at restaurant") == .foodAndDrink)
        #expect(LocalHeuristicSpendingCategorizer.category(for: "mysterious gadget thing") == .awkward)
    }

    @Test func appleIntelligenceCategoryParserAcceptsPlainTextLabels() {
        #expect(AppleIntelligenceSpendingCategorizer.category(from: "Food & Drink") == .foodAndDrink)
        #expect(AppleIntelligenceSpendingCategorizer.category(from: "Category: Work & Education.") == .workAndEducation)
        #expect(AppleIntelligenceSpendingCategorizer.category(from: "`Misc / Awkward`") == .awkward)
        #expect(AppleIntelligenceSpendingCategorizer.category(from: "This should be filed under Fees and Taxes.") == .feesAndTaxes)
        #expect(AppleIntelligenceSpendingCategorizer.category(from: "No matching label") == nil)
    }

    @Test @MainActor func budgetChatInstructionsUseFriendlySpendingLanguage() {
        let instructions = BudgetChatSession.instructions(for: .preview)

        #expect(instructions.contains("casual, friendly budget coach"))
        #expect(instructions.contains("amounts already spent"))
        #expect(instructions.contains("not budget limits or target budgets"))
        #expect(instructions.contains("Spent today"))
        #expect(instructions.contains("Spent this week"))
        #expect(instructions.contains("Spent this month"))
        #expect(instructions.contains("Do not use em dashes"))
        #expect(!instructions.contains("occasionally drop casual bro-speak"))
        #expect(!instructions.contains(" — "))
    }

    @Test func budgetChatMarkdownStripsInlineMarkersForRenderedText() {
        let attributed = BudgetChatMarkdown.attributedString(
            from: "Markdown check: **bold spending**, *friendly tone*, and `daily spent`."
        )

        #expect(String(attributed.characters) == "Markdown check: bold spending, friendly tone, and daily spent.")
    }

    @Test func filteredTransactionsFollowSelectedWindowMode() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2

        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 14, hour: 12)))
        let inCalendarWeek = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let slidingOnly = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 13)))
        let outsideBoth = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 11)))

        let calculator = BudgetCalculator(calendar: calendar)
        let expenses = [
            Expense(amount: 10, note: "calendar week", date: inCalendarWeek, category: .foodAndDrink),
            Expense(amount: 20, note: "sliding only", date: slidingOnly, category: .transport),
            Expense(amount: 30, note: "outside both", date: outsideBoth, category: .groceries)
        ]

        let slidingNotes = calculator.expenses(for: expenses, period: .week, mode: .sliding, now: now).map(\.note)
        let calendarNotes = calculator.expenses(for: expenses, period: .week, mode: .calendar, now: now).map(\.note)

        #expect(slidingNotes == ["calendar week", "sliding only"])
        #expect(calendarNotes == ["calendar week"])
    }

    @Test func comparisonUsesPreviousMatchingWindow() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let calculator = BudgetCalculator(calendar: Calendar(identifier: .gregorian))
        let expenses = [
            Expense(amount: 100, note: "current a", date: now.addingTimeInterval(-1 * 86_400), category: .foodAndDrink),
            Expense(amount: 50, note: "current b", date: now.addingTimeInterval(-2 * 86_400), category: .transport),
            Expense(amount: 50, note: "previous", date: now.addingTimeInterval(-8 * 86_400), category: .groceries),
            Expense(amount: 90, note: "older", date: now.addingTimeInterval(-15 * 86_400), category: .utilities)
        ]

        let comparison = calculator.comparison(for: expenses, period: .week, mode: .sliding, now: now)

        #expect(comparison.currentTotal == 150)
        #expect(comparison.previousTotal == 50)
        #expect(comparison.percentChange == 200)
        #expect(comparison.previousLabel == "previous 7 days")
    }

    @Test @MainActor func recurringExpenseMaterializesMissedOccurrences() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 9)))
        let clock = TestClock(now: start)
        let store = BudgetStore(
            categorizer: StubCategorizer(),
            persistence: InMemoryBudgetPersistence(),
            calendar: calendar,
            updatesWidgets: false,
            nowProvider: { clock.now }
        )

        let template = store.addExpense(amount: 9.99, note: "Streaming", recurrence: .monthly)

        #expect(store.expenses.count == 1)
        #expect(store.expenses[0].nextOccurrenceDate == calendar.date(byAdding: .month, value: 1, to: start))

        clock.now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 6, hour: 9)))
        store.materializeRecurringExpenses()

        let instances = store.expenses.filter { $0.recurringSourceID == template.id }
        #expect(instances.count == 2)
        #expect(instances.allSatisfy { $0.amount == 9.99 && $0.note == "Streaming" })

        let instanceDates = instances.map(\.date).sorted()
        #expect(instanceDates == [
            calendar.date(byAdding: .month, value: 1, to: start),
            calendar.date(byAdding: .month, value: 2, to: start)
        ].compactMap { $0 })
    }

    @Test @MainActor func recurringMaterializationIsIdempotentAndSkipsFutureOccurrences() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12)))
        let clock = TestClock(now: start)
        let store = BudgetStore(
            categorizer: StubCategorizer(),
            persistence: InMemoryBudgetPersistence(),
            calendar: calendar,
            updatesWidgets: false,
            nowProvider: { clock.now }
        )

        store.addExpense(amount: 120, note: "Gym membership", recurrence: .weekly)

        store.materializeRecurringExpenses()
        #expect(store.expenses.count == 1)

        clock.now = start.addingTimeInterval(8 * 86_400)
        store.materializeRecurringExpenses()
        store.materializeRecurringExpenses()
        #expect(store.expenses.count == 2)

        let template = try #require(store.expenses.first { $0.recurrence != nil })
        #expect(template.nextOccurrenceDate == calendar.date(byAdding: .weekOfYear, value: 2, to: start))
    }

    @Test @MainActor func nonRecurringExpenseNeverMaterializesCopies() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let clock = TestClock(now: start)
        let store = BudgetStore(
            categorizer: StubCategorizer(),
            persistence: InMemoryBudgetPersistence(),
            updatesWidgets: false,
            nowProvider: { clock.now }
        )

        store.addExpense(amount: 42, note: "One-off gadget")

        clock.now = start.addingTimeInterval(90 * 86_400)
        store.materializeRecurringExpenses()

        #expect(store.expenses.count == 1)
        #expect(store.expenses[0].nextOccurrenceDate == nil)
    }

    @Test func expenseDecodingToleratesPayloadsWithoutRecurrenceFields() throws {
        let legacyJSON = """
        [{"id":"6F1F4E9A-2B7C-4C57-9B44-2C1F0E2C9A11","amount":12.5,"note":"coffee","date":700000000,"category":"Food & Drink","categorizationState":"categorized"}]
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let expenses = try decoder.decode([Expense].self, from: Data(legacyJSON.utf8))

        #expect(expenses.count == 1)
        #expect(expenses[0].recurrence == nil)
        #expect(expenses[0].recurringSourceID == nil)
        #expect(expenses[0].isRecurring == false)
    }

    @Test func comparisonUsesCurrentTotalWhenPreviousWindowIsZero() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let calculator = BudgetCalculator(calendar: Calendar(identifier: .gregorian))
        let expenses = [
            Expense(amount: 200, note: "new spending", date: now.addingTimeInterval(-60), category: .foodAndDrink)
        ]

        let comparison = calculator.comparison(for: expenses, period: .day, mode: .calendar, now: now)

        #expect(comparison.currentTotal == 200)
        #expect(comparison.previousTotal == 0)
        #expect(comparison.percentChange == 200)
        #expect(comparison.previousLabel == "yesterday")
    }
}

private final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private struct StubCategorizer: SpendingCategorizing {
    func categorize(description: String, amount: Decimal) async throws -> SpendingCategory {
        .subscriptions
    }
}

@MainActor
private final class InMemoryBudgetPersistence: BudgetPersisting {
    private var expenses: [Expense] = []
    private var monthWindowMode: SpendingWindowMode?
    private var weekWindowMode: SpendingWindowMode?

    func loadExpenses() -> [Expense] { expenses }
    func saveExpenses(_ expenses: [Expense]) { self.expenses = expenses }
    func loadMonthWindowMode() -> SpendingWindowMode? { monthWindowMode }
    func saveMonthWindowMode(_ mode: SpendingWindowMode) { monthWindowMode = mode }
    func loadWeekWindowMode() -> SpendingWindowMode? { weekWindowMode }
    func saveWeekWindowMode(_ mode: SpendingWindowMode) { weekWindowMode = mode }
}
