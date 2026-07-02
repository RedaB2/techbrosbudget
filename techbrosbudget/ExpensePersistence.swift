//
//  ExpensePersistence.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 6/14/26.
//

import Foundation
import SwiftData

@MainActor
protocol BudgetPersisting {
    func loadExpenses() -> [Expense]
    func saveExpenses(_ expenses: [Expense])
    func loadMonthWindowMode() -> SpendingWindowMode?
    func saveMonthWindowMode(_ mode: SpendingWindowMode)
    func loadWeekWindowMode() -> SpendingWindowMode?
    func saveWeekWindowMode(_ mode: SpendingWindowMode)
}

enum BudgetPersistenceFactory {
    static func makeDefault() -> BudgetPersisting {
        do {
            let cloudStore = try SwiftDataBudgetStore()
            UserDefaultsBudgetStore().migrateIfNeeded(to: cloudStore)
            return cloudStore
        } catch {
            return UserDefaultsBudgetStore()
        }
    }
}

@Model
final class PersistedExpense {
    var id: UUID = UUID()
    var amount: String = "0"
    var note: String = ""
    var date: Date = Date()
    var category: String = SpendingCategory.awkward.rawValue
    var categorizationState: String = CategorizationState.pending.rawValue
    var recurrence: String?
    var nextOccurrenceDate: Date?
    var recurringSourceID: UUID?

    init(expense: Expense) {
        self.id = expense.id
        self.amount = NSDecimalNumber(decimal: expense.amount).stringValue
        self.note = expense.note
        self.date = expense.date
        self.category = expense.category.rawValue
        self.categorizationState = expense.categorizationState.rawValue
        self.recurrence = expense.recurrence?.rawValue
        self.nextOccurrenceDate = expense.nextOccurrenceDate
        self.recurringSourceID = expense.recurringSourceID
    }

    func update(from expense: Expense) {
        amount = NSDecimalNumber(decimal: expense.amount).stringValue
        note = expense.note
        date = expense.date
        category = expense.category.rawValue
        categorizationState = expense.categorizationState.rawValue
        recurrence = expense.recurrence?.rawValue
        nextOccurrenceDate = expense.nextOccurrenceDate
        recurringSourceID = expense.recurringSourceID
    }

    var expense: Expense {
        Expense(
            id: id,
            amount: Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX")) ?? .zero,
            note: note,
            date: date,
            category: SpendingCategory(rawValue: category) ?? .awkward,
            categorizationState: CategorizationState(rawValue: categorizationState) ?? .needsReview,
            recurrence: recurrence.flatMap(RecurrenceFrequency.init(rawValue:)),
            nextOccurrenceDate: nextOccurrenceDate,
            recurringSourceID: recurringSourceID
        )
    }
}

@Model
final class PersistedBudgetPreferences {
    var id: String = "budgetPreferences"
    var monthWindowMode: String = SpendingWindowMode.sliding.rawValue
    var weekWindowMode: String = SpendingWindowMode.sliding.rawValue

    init() {}
}

@MainActor
final class SwiftDataBudgetStore: BudgetPersisting {
    static let cloudKitContainerIdentifier = "iCloud.reda.techbrosbudget"

    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        let schema = Schema([
            PersistedExpense.self,
            PersistedBudgetPreferences.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        self.container = container
        self.context = ModelContext(container)
    }

    func loadExpenses() -> [Expense] {
        let descriptor = FetchDescriptor<PersistedExpense>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        return ((try? context.fetch(descriptor)) ?? []).map(\.expense)
    }

    func saveExpenses(_ expenses: [Expense]) {
        let existing = ((try? context.fetch(FetchDescriptor<PersistedExpense>())) ?? [])
        var existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingIDs = Set(expenses.map(\.id))

        for expense in expenses {
            if let persisted = existingByID.removeValue(forKey: expense.id) {
                persisted.update(from: expense)
            } else {
                context.insert(PersistedExpense(expense: expense))
            }
        }

        for staleExpense in existing where !incomingIDs.contains(staleExpense.id) {
            context.delete(staleExpense)
        }

        try? context.save()
    }

    func loadMonthWindowMode() -> SpendingWindowMode? {
        existingPreferences().flatMap { SpendingWindowMode(rawValue: $0.monthWindowMode) }
    }

    func saveMonthWindowMode(_ mode: SpendingWindowMode) {
        preferences().monthWindowMode = mode.rawValue
        try? context.save()
    }

    func loadWeekWindowMode() -> SpendingWindowMode? {
        existingPreferences().flatMap { SpendingWindowMode(rawValue: $0.weekWindowMode) }
    }

    func saveWeekWindowMode(_ mode: SpendingWindowMode) {
        preferences().weekWindowMode = mode.rawValue
        try? context.save()
    }

    private func preferences() -> PersistedBudgetPreferences {
        if let existing = existingPreferences() {
            return existing
        }

        let preferences = PersistedBudgetPreferences()
        context.insert(preferences)
        try? context.save()
        return preferences
    }

    private func existingPreferences() -> PersistedBudgetPreferences? {
        try? context.fetch(FetchDescriptor<PersistedBudgetPreferences>()).first
    }
}

@MainActor
struct UserDefaultsBudgetStore: BudgetPersisting {
    private let expensesKey: String
    private let monthWindowKey: String
    private let weekWindowKey: String
    private let migrationKey: String
    private let defaults: UserDefaults

    init(
        expensesKey: String = "techbrosbudget.expenses",
        monthWindowKey: String = "techbrosbudget.monthWindowMode",
        weekWindowKey: String = "techbrosbudget.weekWindowMode",
        migrationKey: String = "techbrosbudget.didMigrateUserDefaultsToCloudKit",
        defaults: UserDefaults = .standard
    ) {
        self.expensesKey = expensesKey
        self.monthWindowKey = monthWindowKey
        self.weekWindowKey = weekWindowKey
        self.migrationKey = migrationKey
        self.defaults = defaults
    }

    func loadExpenses() -> [Expense] {
        guard let data = defaults.data(forKey: expensesKey) else {
            return []
        }

        return (try? JSONDecoder().decode([Expense].self, from: data)) ?? []
    }

    func saveExpenses(_ expenses: [Expense]) {
        guard let data = try? JSONEncoder().encode(expenses) else {
            return
        }

        defaults.set(data, forKey: expensesKey)
    }

    func loadMonthWindowMode() -> SpendingWindowMode? {
        defaults.string(forKey: monthWindowKey).flatMap(SpendingWindowMode.init(rawValue:))
    }

    func saveMonthWindowMode(_ mode: SpendingWindowMode) {
        defaults.set(mode.rawValue, forKey: monthWindowKey)
    }

    func loadWeekWindowMode() -> SpendingWindowMode? {
        defaults.string(forKey: weekWindowKey).flatMap(SpendingWindowMode.init(rawValue:))
    }

    func saveWeekWindowMode(_ mode: SpendingWindowMode) {
        defaults.set(mode.rawValue, forKey: weekWindowKey)
    }

    func migrateIfNeeded(to cloudStore: BudgetPersisting) {
        guard !defaults.bool(forKey: migrationKey) else {
            return
        }

        let localExpenses = loadExpenses()
        let cloudExpenses = cloudStore.loadExpenses()

        if !localExpenses.isEmpty && cloudExpenses.isEmpty {
            cloudStore.saveExpenses(localExpenses)
        }

        if let monthWindowMode = loadMonthWindowMode(), cloudStore.loadMonthWindowMode() == nil {
            cloudStore.saveMonthWindowMode(monthWindowMode)
        }

        if let weekWindowMode = loadWeekWindowMode(), cloudStore.loadWeekWindowMode() == nil {
            cloudStore.saveWeekWindowMode(weekWindowMode)
        }

        defaults.set(true, forKey: migrationKey)
    }
}
