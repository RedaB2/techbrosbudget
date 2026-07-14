//
//  AutoCaptureTests.swift
//  techbrosbudgetTests
//
//  Created by Claude on 7/11/26.
//

import Foundation
import Testing
@testable import techbrosbudget

struct TransactionNotificationHeuristicsTests {
    @Test func walletStylePushUsesTitleAsMerchant() throws {
        let parsed = try #require(TransactionNotificationHeuristics.parse(
            title: "Blue Bottle Coffee",
            body: "$6.50 with Apple Pay"
        ))

        #expect(parsed.amount == 6.50)
        #expect(parsed.merchant == "Blue Bottle Coffee")
    }

    @Test func bankPushExtractsMerchantAfterAtKeyword() throws {
        let parsed = try #require(TransactionNotificationHeuristics.parse(
            title: "Purchase Alert",
            body: "You made a $23.40 transaction with your Visa card at WHOLE FOODS MARKET."
        ))

        #expect(parsed.amount == 23.40)
        #expect(parsed.merchant == "WHOLE FOODS MARKET")
    }

    @Test func merchantStopsBeforeTrailingDate() throws {
        let parsed = try #require(TransactionNotificationHeuristics.parse(
            title: nil,
            body: "Your card ending in 4029 was charged $12.99 at NETFLIX.COM on Jul 11."
        ))

        #expect(parsed.amount == 12.99)
        #expect(parsed.merchant == "NETFLIX.COM")
    }

    @Test func timeOfDayIsNotMistakenForMerchant() throws {
        let parsed = try #require(TransactionNotificationHeuristics.parse(
            title: nil,
            body: "Transaction approved at 3:45 PM at STARBUCKS for $8.20"
        ))

        #expect(parsed.amount == 8.20)
        #expect(parsed.merchant == "STARBUCKS")
    }

    @Test func europeanFormatParsesCommaDecimalAndChezKeyword() throws {
        let parsed = try #require(TransactionNotificationHeuristics.parse(
            title: nil,
            body: "Paiement de 12,50 € chez Carrefour"
        ))

        #expect(parsed.amount == 12.50)
        #expect(parsed.merchant == "Carrefour")
    }

    @Test func thousandsSeparatorsParseCorrectly() throws {
        let parsed = try #require(TransactionNotificationHeuristics.parse(
            title: nil,
            body: "You spent $1,234.56 at BEST BUY"
        ))

        #expect(parsed.amount == Decimal(string: "1234.56"))
    }

    @Test func genericTitleFallsBackToPlaceholderMerchant() throws {
        let parsed = try #require(TransactionNotificationHeuristics.parse(
            title: "Purchase Alert",
            body: "Card ending 4029 was used for $18.20."
        ))

        #expect(parsed.amount == 18.20)
        #expect(parsed.merchant == "Card purchase")
    }

    @Test func nonPurchaseNotificationsAreRejected() {
        #expect(TransactionNotificationHeuristics.parse(
            title: "Chase",
            body: "A refund of $23.40 from WHOLE FOODS was posted to your account."
        ) == nil)

        #expect(TransactionNotificationHeuristics.parse(
            title: "Bank",
            body: "Your verification code is 482913."
        ) == nil)

        #expect(TransactionNotificationHeuristics.parse(
            title: "Messages",
            body: "Hey, are we still on for lunch?"
        ) == nil)
    }

    @Test func amountTokensNormalizeBothSeparatorConventions() {
        #expect(TransactionNotificationHeuristics.decimalAmount(fromToken: "4,50") == 4.50)
        #expect(TransactionNotificationHeuristics.decimalAmount(fromToken: "4,500") == 4500)
        #expect(TransactionNotificationHeuristics.decimalAmount(fromToken: "1.234,56") == Decimal(string: "1234.56"))
        #expect(TransactionNotificationHeuristics.decimalAmount(fromToken: "1,234.56") == Decimal(string: "1234.56"))
        #expect(TransactionNotificationHeuristics.decimalAmount(fromToken: "12.5") == 12.5)
        #expect(TransactionNotificationHeuristics.decimalAmount(fromToken: "1.234") == 1234)
        #expect(TransactionNotificationHeuristics.decimalAmount(fromToken: "0") == nil)
    }

    @Test func modelOutputParsesAmountPipeMerchant() throws {
        let parsed = try #require(TransactionNotificationParser.parsedTransaction(
            fromModelOutput: " 23.40 | WHOLE FOODS MARKET "
        ))

        #expect(parsed.amount == 23.40)
        #expect(parsed.merchant == "WHOLE FOODS MARKET")

        #expect(TransactionNotificationParser.parsedTransaction(fromModelOutput: "none") == nil)
        #expect(TransactionNotificationParser.parsedTransaction(fromModelOutput: "no amount here") == nil)
    }
}

struct AutoCaptureDedupTests {
    @Test @MainActor func autoCapturedExpenseCarriesItsSource() {
        let store = makeStore(now: Date(timeIntervalSince1970: 1_000_000))

        let result = store.recordAutoCapturedExpense(amount: 6.50, merchant: "Blue Bottle", source: .walletAutomation)

        #expect(result.isDuplicate == false)
        #expect(result.expense.source == .walletAutomation)
        #expect(result.expense.isAutoCaptured)
        #expect(store.expenses.count == 1)
    }

    @Test @MainActor func sameAmountWithinWindowIsSkippedAsDuplicate() {
        let store = makeStore(now: Date(timeIntervalSince1970: 1_000_000))

        let first = store.recordAutoCapturedExpense(amount: 23.40, merchant: "Whole Foods", source: .walletAutomation)
        let second = store.recordAutoCapturedExpense(amount: 23.40, merchant: "WHOLE FOODS MARKET", source: .notificationAutomation)

        #expect(second.isDuplicate)
        #expect(second.expense.id == first.expense.id)
        #expect(store.expenses.count == 1)
    }

    @Test @MainActor func sameAmountOutsideWindowLogsSeparately() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let clock = AutoCaptureTestClock(now: start)
        let store = makeStore(clock: clock)

        store.recordAutoCapturedExpense(amount: 4.75, merchant: "Blue Bottle", source: .walletAutomation)

        clock.now = start.addingTimeInterval(BudgetStore.autoCaptureDuplicateWindow + 60)
        let second = store.recordAutoCapturedExpense(amount: 4.75, merchant: "Blue Bottle", source: .walletAutomation)

        #expect(second.isDuplicate == false)
        #expect(store.expenses.count == 2)
    }

    @Test @MainActor func duplicateUpgradesPlaceholderNote() {
        let store = makeStore(now: Date(timeIntervalSince1970: 1_000_000))

        store.recordAutoCapturedExpense(amount: 18.20, merchant: "Expense", source: .notificationAutomation)
        let second = store.recordAutoCapturedExpense(amount: 18.20, merchant: "Shell", source: .walletAutomation)

        #expect(second.isDuplicate)
        #expect(second.expense.note == "Shell")
        #expect(store.expenses.count == 1)
    }

    @Test @MainActor func manualEntryWithinWindowSuppressesAutoCapture() {
        let store = makeStore(now: Date(timeIntervalSince1970: 1_000_000))

        store.addExpense(amount: 8.20, note: "starbucks run")
        let captured = store.recordAutoCapturedExpense(amount: 8.20, merchant: "STARBUCKS", source: .walletAutomation)

        #expect(captured.isDuplicate)
        #expect(captured.expense.note == "starbucks run")
        #expect(store.expenses.count == 1)
    }

    @MainActor
    private func makeStore(now: Date) -> BudgetStore {
        makeStore(clock: AutoCaptureTestClock(now: now))
    }

    @MainActor
    private func makeStore(clock: AutoCaptureTestClock) -> BudgetStore {
        BudgetStore(
            categorizer: AutoCaptureStubCategorizer(),
            persistence: AutoCaptureInMemoryPersistence(),
            updatesWidgets: false,
            nowProvider: { clock.now }
        )
    }
}

private final class AutoCaptureTestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private struct AutoCaptureStubCategorizer: SpendingCategorizing {
    func categorize(description: String, amount: Decimal) async throws -> SpendingCategory {
        .foodAndDrink
    }
}

@MainActor
private final class AutoCaptureInMemoryPersistence: BudgetPersisting {
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
