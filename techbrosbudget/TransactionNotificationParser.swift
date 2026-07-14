//
//  TransactionNotificationParser.swift
//  techbrosbudget
//
//  Created by Claude on 7/11/26.
//

import Foundation
import FoundationModels
import os

struct ParsedTransactionNotification: Equatable {
    let amount: Decimal
    let merchant: String
}

protocol TransactionNotificationParsing {
    func parse(title: String?, body: String?) async -> ParsedTransactionNotification?
}

/// Turns the free-text payload of a Wallet or banking-app push notification
/// (delivered by the iOS 27 Shortcuts Notification trigger) into an amount and
/// merchant. Deterministic heuristics cover the common formats; the on-device
/// Foundation Models session picks up bank formats the heuristics don't know.
struct TransactionNotificationParser: TransactionNotificationParsing {
    private static let logger = Logger(subsystem: "reda.techbrosbudget", category: "TransactionNotificationParser")

    private let model: SystemLanguageModel

    init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    func parse(title: String?, body: String?) async -> ParsedTransactionNotification? {
        if let parsed = TransactionNotificationHeuristics.parse(title: title, body: body) {
            return parsed
        }

        return await modelParse(title: title, body: body)
    }

    private func modelParse(title: String?, body: String?) async -> ParsedTransactionNotification? {
        guard model.isAvailable else {
            return nil
        }

        let prompt = """
        Title: \(title ?? "")
        Message: \(body ?? "")
        """

        do {
            return Self.parsedTransaction(fromModelOutput: try await respond(using: model, prompt: prompt))
        } catch where FoundationModelsFailure.isSafetyModelFailure(error) {
            Self.logger.error("Safety classifier failed; retrying with relaxed guardrails: \(error, privacy: .public)")
        } catch {
            Self.logger.error("Notification extraction failed: \(error, privacy: .public)")
            return nil
        }

        do {
            let relaxedModel = SystemLanguageModel(guardrails: .permissiveContentTransformations)
            return Self.parsedTransaction(fromModelOutput: try await respond(using: relaxedModel, prompt: prompt))
        } catch {
            Self.logger.error("Relaxed-guardrails notification extraction failed: \(error, privacy: .public)")
            return nil
        }
    }

    private func respond(using model: SystemLanguageModel, prompt: String) async throws -> String {
        let session = LanguageModelSession(model: model, instructions: Self.extractionInstructions)
        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(temperature: 0.1)
        )
        return response.content
    }

    static let extractionInstructions = """
    You extract purchase details from a bank or Apple Wallet push notification.

    Rules:
    - Respond with exactly one line in the format: amount | merchant
    - The amount is a plain number with a dot decimal separator and no currency symbol.
    - The merchant is the store, brand, or payee name only — no card numbers, dates, or filler words.
    - If the notification is not a card purchase (a refund, deposit, incoming transfer, one-time code, balance alert, payment reminder), respond with exactly: none

    Examples:
    "Your Visa card was charged $23.40 at WHOLE FOODS MARKET on Jul 11" -> 23.40 | WHOLE FOODS MARKET
    "Débit carte 45,00 € - SHELL 5742" -> 45.00 | SHELL
    "Your verification code is 482913" -> none
    """

    static func parsedTransaction(fromModelOutput output: String) -> ParsedTransactionNotification? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased() != "none" else {
            return nil
        }

        let parts = trimmed.components(separatedBy: "|")
        guard parts.count >= 2,
              let amount = MoneyParser.decimal(from: parts[0]),
              amount > 0
        else {
            return nil
        }

        let merchant = TransactionNotificationHeuristics.cleanedMerchant(
            parts[1...].joined(separator: "|")
        )
        guard !merchant.isEmpty else {
            return nil
        }

        return ParsedTransactionNotification(amount: amount, merchant: merchant)
    }
}

enum TransactionNotificationHeuristics {
    /// Words that mark a notification as money coming in or non-transactional —
    /// logging those as expenses would corrupt the ledger, so they hard-stop
    /// parsing (the model fallback is instructed the same way).
    private static let nonPurchaseMarkers = [
        "refund", "reversal", "deposited", "deposit of", "credited", "you received",
        "verification code", "one-time", "security code", "payment due", "statement is ready"
    ]

    private static let genericTitles: Set<String> = [
        "apple pay", "apple card", "apple cash", "wallet", "purchase", "payment",
        "transaction", "card transaction", "purchase alert", "transaction alert",
        "debit card purchase", "credit card purchase", "card charge", "alert", "notification"
    ]

    private static let merchantKeywords = ["at", "to", "from", "chez"]

    private static let merchantStops = [
        " on ", " using ", " with ", " via ", " for ", " was ", " ending ", ", ", ". ", "; ", " – ", " - ", "\n"
    ]

    static func parse(title: String?, body: String?) -> ParsedTransactionNotification? {
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let combined = [title, body].filter { !$0.isEmpty }.joined(separator: "\n")

        guard !combined.isEmpty else {
            return nil
        }

        let lowered = combined.lowercased()
        guard !nonPurchaseMarkers.contains(where: lowered.contains) else {
            return nil
        }

        guard let amount = firstAmount(in: body) ?? firstAmount(in: title) else {
            return nil
        }

        let merchant = keywordMerchant(in: body)
            ?? keywordMerchant(in: title)
            ?? titleMerchant(from: title)
            ?? "Card purchase"

        return ParsedTransactionNotification(amount: amount, merchant: merchant)
    }

    // MARK: - Amount

    // Symbol or code before the number ("$23.40", "USD 23.40", "MAD 120").
    private static let currencyLedAmount = #/(?:[$€£¥]|(?i:USD|EUR|GBP|CAD|AUD|CHF|MAD))\s*([0-9][0-9.,]*[0-9]|[0-9])/#

    // Number before the symbol or currency word ("4,50 €", "23.40 USD", "12 dollars").
    private static let amountLedCurrency = #/([0-9][0-9.,]*[0-9]|[0-9])\s*(?:[€£¥]|(?i:USD|EUR|GBP|CAD|AUD|CHF|MAD|dollars?|euros?))\b/#

    static func firstAmount(in text: String) -> Decimal? {
        guard !text.isEmpty else {
            return nil
        }

        if let match = text.firstMatch(of: currencyLedAmount) {
            return decimalAmount(fromToken: String(match.1))
        }

        if let match = text.firstMatch(of: amountLedCurrency) {
            return decimalAmount(fromToken: String(match.1))
        }

        return nil
    }

    /// Handles both separator conventions: "1,234.56" and "1.234,56" both
    /// parse as 1234.56, and a lone trailing group of one or two digits is the
    /// decimal part ("4,50" is 4.50 while "4,500" is four thousand five hundred).
    static func decimalAmount(fromToken token: String) -> Decimal? {
        var normalized = token

        let lastComma = normalized.range(of: ",", options: .backwards)
        let lastDot = normalized.range(of: ".", options: .backwards)

        let decimalSeparator: String?
        switch (lastComma, lastDot) {
        case (let comma?, let dot?):
            decimalSeparator = comma.lowerBound > dot.lowerBound ? "," : "."
        case (.some, nil):
            decimalSeparator = isDecimalSeparator(",", in: normalized) ? "," : nil
        case (nil, .some):
            decimalSeparator = isDecimalSeparator(".", in: normalized) ? "." : nil
        case (nil, nil):
            decimalSeparator = nil
        }

        if let separator = decimalSeparator {
            let grouping = separator == "," ? "." : ","
            normalized = normalized.replacingOccurrences(of: grouping, with: "")
            normalized = normalized.replacingOccurrences(of: separator, with: ".")
        } else {
            normalized = normalized
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: ".", with: "")
        }

        guard let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), amount > 0 else {
            return nil
        }

        var rounded = Decimal()
        var value = amount
        NSDecimalRound(&rounded, &value, 2, .plain)
        return rounded
    }

    private static func isDecimalSeparator(_ separator: Character, in token: String) -> Bool {
        guard token.filter({ $0 == separator }).count == 1,
              let index = token.lastIndex(of: separator)
        else {
            return false
        }

        let fractionDigits = token.distance(from: token.index(after: index), to: token.endIndex)
        return fractionDigits >= 1 && fractionDigits <= 2
    }

    // MARK: - Merchant

    static func keywordMerchant(in text: String) -> String? {
        guard !text.isEmpty else {
            return nil
        }

        for keyword in merchantKeywords {
            var searchRange = text.startIndex..<text.endIndex

            while let keywordRange = text.range(
                of: "\\b\(keyword)\\s+",
                options: [.regularExpression, .caseInsensitive],
                range: searchRange
            ) {
                let candidate = cleanedMerchant(String(text[keywordRange.upperBound...]))
                if isPlausibleMerchant(candidate) {
                    return candidate
                }
                searchRange = keywordRange.upperBound..<text.endIndex
            }
        }

        return nil
    }

    /// A Wallet push often carries the merchant as its title ("Blue Bottle
    /// Coffee") with the amount in the body — but bank pushes title themselves
    /// generically ("Purchase Alert"), which must not become the merchant.
    static func titleMerchant(from title: String) -> String? {
        let candidate = cleanedMerchant(title)

        guard isPlausibleMerchant(candidate),
              !candidate.contains(where: \.isNumber),
              !genericTitles.contains(candidate.lowercased())
        else {
            return nil
        }

        return candidate
    }

    static func cleanedMerchant(_ text: String) -> String {
        var merchant = text.trimmingCharacters(in: .whitespacesAndNewlines)

        var stopIndex = merchant.endIndex
        for stop in merchantStops {
            if let range = merchant.range(of: stop, options: .caseInsensitive), range.lowerBound < stopIndex {
                stopIndex = range.lowerBound
            }
        }
        merchant = String(merchant[..<stopIndex])

        return merchant.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;:!-–"))
        )
    }

    private static func isPlausibleMerchant(_ candidate: String) -> Bool {
        guard !candidate.isEmpty,
              candidate.count <= 60,
              candidate.contains(where: \.isLetter),
              let first = candidate.first,
              !first.isNumber
        else {
            return false
        }

        let lowered = candidate.lowercased()
        let fillerPrefixes = ["your ", "the ", "a ", "an ", "card ", "checking", "savings"]
        return !fillerPrefixes.contains(where: lowered.hasPrefix)
    }
}
