//
//  AutoCaptureIntents.swift
//  techbrosbudget
//
//  Created by Claude on 7/11/26.
//
//  These intents are the receiving end of the auto-capture Shortcuts
//  automations: the Wallet transaction trigger (iOS 26) passes structured
//  merchant + amount, and the Notification trigger (iOS 27) passes the raw
//  title/body of a Wallet or banking-app push. Deployed automations reference
//  these intents by their type name and parameter names — treat both as a
//  frozen public API.
//

import AppIntents
import Foundation

struct AutoCaptureRecord {
    let formattedAmount: String
    let merchant: String
    let isDuplicate: Bool
}

struct LogWalletTransactionIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Wallet Transaction" }

    static var description: IntentDescription? {
        IntentDescription(
            "Logs a tap-to-pay purchase in Tech Bros Budget. Attach it to a Shortcuts Wallet automation and pass the transaction's amount and merchant.",
            searchKeywords: ["spending", "budget", "transaction", "tap to pay", "automatic"]
        )
    }

    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) spent at \(\.$merchant)")
    }

    @Parameter(
        title: "Amount",
        description: "The transaction amount from the Wallet automation.",
        controlStyle: .field,
        requestValueDialog: "How much was the transaction?"
    )
    var amount: Double

    @Parameter(
        title: "Merchant",
        description: "The merchant name from the Wallet automation.",
        requestValueDialog: "Where was it spent?"
    )
    var merchant: String

    init() {}

    init(amount: Double, merchant: String) {
        self.amount = amount
        self.merchant = merchant
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let decimalAmount = SpokenExpenseInput.decimalAmount(from: amount) else {
            throw AutoCaptureIntentError.invalidAmount
        }

        let record = await AutoCaptureRecorder.record(
            amount: decimalAmount,
            merchant: merchant,
            source: .walletAutomation
        )

        return .result(dialog: record.dialog)
    }
}

struct LogTransactionNotificationIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Transaction Notification" }

    static var description: IntentDescription? {
        IntentDescription(
            "Reads a Wallet or banking-app notification and logs the purchase in Tech Bros Budget. Attach it to a Shortcuts Notification automation (iOS 27) and pass the notification's title and body.",
            searchKeywords: ["spending", "budget", "transaction", "notification", "automatic"]
        )
    }

    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    static var parameterSummary: some ParameterSummary {
        Summary("Log the purchase in \(\.$notificationBody) titled \(\.$notificationTitle)")
    }

    @Parameter(
        title: "Notification Title",
        description: "The notification's title from the Notification automation.",
        requestValueDialog: "What was the notification's title?"
    )
    var notificationTitle: String?

    @Parameter(
        title: "Notification Body",
        description: "The notification's message text from the Notification automation.",
        requestValueDialog: "What did the notification say?"
    )
    var notificationBody: String?

    init() {}

    init(notificationTitle: String?, notificationBody: String?) {
        self.notificationTitle = notificationTitle
        self.notificationBody = notificationBody
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let parsed = await TransactionNotificationParser().parse(
            title: notificationTitle,
            body: notificationBody
        ) else {
            throw AutoCaptureIntentError.unrecognizedNotification
        }

        let record = await AutoCaptureRecorder.record(
            amount: parsed.amount,
            merchant: parsed.merchant,
            source: .notificationAutomation
        )

        return .result(dialog: record.dialog)
    }
}

enum AutoCaptureRecorder {
    static func record(amount: Decimal, merchant: String, source: ExpenseSource) async -> AutoCaptureRecord {
        let normalizedMerchant = SpokenExpenseInput.normalizedNote(merchant)

        return await MainActor.run {
            let result = BudgetStore().recordAutoCapturedExpense(
                amount: amount,
                merchant: normalizedMerchant,
                source: source
            )

            return AutoCaptureRecord(
                formattedAmount: MoneyFormatter.currency(amount),
                merchant: normalizedMerchant,
                isDuplicate: result.isDuplicate
            )
        }
    }
}

extension AutoCaptureRecord {
    nonisolated var dialog: IntentDialog {
        isDuplicate
            ? "Skipped — \(formattedAmount) at \(merchant) was already logged."
            : "Added \(formattedAmount) at \(merchant)."
    }
}

enum AutoCaptureIntentError: LocalizedError {
    case invalidAmount
    case unrecognizedNotification

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "The transaction amount must be greater than zero."
        case .unrecognizedNotification:
            return "Couldn't find a purchase amount in that notification, so nothing was logged."
        }
    }
}
