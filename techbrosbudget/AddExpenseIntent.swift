//
//  AddExpenseIntent.swift
//  techbrosbudget
//
//  Created by OpenAI on 6/28/26.
//

import AppIntents
import Foundation

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Add Expense" }

    static var description: IntentDescription? {
        IntentDescription(
            "Records an expense in Tech Bros Budget from Siri or Shortcuts.",
            searchKeywords: ["spending", "budget", "transaction"]
        )
    }

    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) spent on \(\.$note)")
    }

    @Parameter(
        title: "Amount",
        description: "The amount spent.",
        controlStyle: .field,
        requestValueDialog: "How much did you spend?"
    )
    var amount: Double

    @Parameter(
        title: "Note",
        description: "What the money was spent on.",
        requestValueDialog: "What was it for?"
    )
    var note: String

    init() {}

    init(amount: Double, note: String) {
        self.amount = amount
        self.note = note
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let decimalAmount = SiriExpenseInput.decimalAmount(from: amount) else {
            throw AddExpenseIntentError.invalidAmount
        }

        let result = await ExpenseIntentRecorder.record(amount: decimalAmount, note: note)

        return .result(dialog: "Added \(result.formattedAmount) for \(result.note).")
    }
}

struct RecordSpokenExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Record Spoken Expense" }

    static var description: IntentDescription? {
        IntentDescription(
            "Records a dictated expense such as '74 on coffee' in Tech Bros Budget.",
            searchKeywords: ["spending", "budget", "transaction", "Siri"]
        )
    }

    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    static var parameterSummary: some ParameterSummary {
        Summary("Record \(\.$spokenExpense)")
    }

    @Parameter(
        title: "Expense",
        description: "The amount and what it was for, such as '74 on coffee'.",
        requestValueDialog: "What did you spend?"
    )
    var spokenExpense: SpokenExpenseEntity

    init() {}

    init(spokenExpense: String) {
        self.spokenExpense = SpokenExpenseEntity(text: spokenExpense)
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let parsedExpense = SiriExpenseInput.parsedExpense(from: spokenExpense.text) else {
            throw AddExpenseIntentError.invalidSpokenExpense
        }

        let result = await ExpenseIntentRecorder.record(
            amount: parsedExpense.amount,
            note: parsedExpense.note
        )

        return .result(dialog: "Added \(result.formattedAmount) for \(result.note).")
    }
}

struct BudgetAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordSpokenExpenseIntent(),
            phrases: [
                "I spent \(\.$spokenExpense) in \(.applicationName)",
                "In \(.applicationName) I spent \(\.$spokenExpense)",
                "Add \(\.$spokenExpense) in \(.applicationName)",
                "Log \(\.$spokenExpense) in \(.applicationName)",
                "Record \(\.$spokenExpense) in \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor { .teal }
}

struct SpokenExpenseEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Expense" }
    static var defaultQuery = SpokenExpenseQuery()

    let id: String

    init(text: String) {
        self.id = text
    }

    var text: String { id }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

struct SpokenExpenseQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpokenExpenseEntity] {
        identifiers.map(SpokenExpenseEntity.init(text:))
    }

    func entities(matching string: String) async throws -> [SpokenExpenseEntity] {
        [SpokenExpenseEntity(text: string)]
    }

    func suggestedEntities() async throws -> [SpokenExpenseEntity] {
        []
    }
}

struct ParsedSiriExpense: Equatable {
    let amount: Decimal
    let note: String
}

enum SiriExpenseInput {
    nonisolated static func decimalAmount(from amount: Double) -> Decimal? {
        guard amount.isFinite else {
            return nil
        }

        let cents = (amount * 100).rounded(.toNearestOrAwayFromZero)
        guard cents > 0, cents <= Double(Int64.max) else {
            return nil
        }

        return Decimal(Int64(cents)) / Decimal(100)
    }

    nonisolated static func parsedExpense(from spokenExpense: String) -> ParsedSiriExpense? {
        let trimmed = strippedSpendingPrefix(from: spokenExpense)
        guard !trimmed.isEmpty else {
            return nil
        }

        let scanner = Scanner(string: trimmed)
        scanner.charactersToBeSkipped = .whitespacesAndNewlines
        _ = scanner.scanCharacters(from: CharacterSet(charactersIn: "$€£¥"))

        guard
            let amountToken = scanner.scanCharacters(from: CharacterSet(charactersIn: "0123456789.,"))
        else {
            return nil
        }

        guard let amount = decimalAmount(fromToken: amountToken) else {
            return nil
        }

        let remainder = String(trimmed[scanner.currentIndex...])
        let note = normalizedNote(strippedConnectorPrefix(from: remainder))
        return ParsedSiriExpense(amount: amount, note: note)
    }

    nonisolated static func normalizedNote(_ note: String) -> String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Expense" : trimmed
    }

    private nonisolated static func decimalAmount(fromToken amountToken: String) -> Decimal? {
        let cleaned = amountToken.replacingOccurrences(of: ",", with: "")

        guard
            var amount = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")),
            amount > 0
        else {
            return nil
        }

        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 2, .plain)
        return rounded
    }

    private nonisolated static func strippedSpendingPrefix(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        for prefix in ["i spent ", "spent ", "i paid ", "paid "] {
            if lowercased.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return trimmed
    }

    private nonisolated static func strippedConnectorPrefix(from text: String) -> String {
        var words = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)

        while let first = words.first?.lowercased(), ["dollar", "dollars", "buck", "bucks", "usd"].contains(first) {
            words.removeFirst()
        }

        if let first = words.first?.lowercased(), ["on", "for", "at"].contains(first) {
            words.removeFirst()
        }

        return words.joined(separator: " ")
    }
}

private enum ExpenseIntentRecorder {
    static func record(amount: Decimal, note: String) async -> (formattedAmount: String, note: String) {
        let normalizedNote = SiriExpenseInput.normalizedNote(note)

        let formattedAmount = await MainActor.run {
            _ = BudgetStore().addExpense(amount: amount, note: normalizedNote)
            return MoneyFormatter.currency(amount)
        }

        return (formattedAmount, normalizedNote)
    }
}

private enum AddExpenseIntentError: LocalizedError {
    case invalidAmount
    case invalidSpokenExpense

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "The expense amount must be greater than zero."
        case .invalidSpokenExpense:
            return "Say the amount followed by what it was for, such as '74 on coffee'."
        }
    }
}
