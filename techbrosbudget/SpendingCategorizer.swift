//
//  SpendingCategorizer.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 6/14/26.
//

import Foundation
import FoundationModels
import os

protocol SpendingCategorizing {
    func categorize(description: String, amount: Decimal) async throws -> SpendingCategory
}

struct AppleIntelligenceSpendingCategorizer: SpendingCategorizing {
    static let allowedCategoryNames = SpendingCategory.allCases.map(\.apiName)

    private static let logger = Logger(subsystem: "reda.techbrosbudget", category: "SpendingCategorizer")

    // On some iOS 26 builds the system safety classifier fails to load and
    // every generation request throws even though the language model works
    // (see FoundationModelsFailure). Once detected, later expenses skip the
    // doomed standard attempt and go straight to relaxed guardrails.
    private static let safetyModelIsBroken = OSAllocatedUnfairLock(initialState: false)

    private let model: SystemLanguageModel
    private let fallbackCategorizer: LocalHeuristicSpendingCategorizer

    init(model: SystemLanguageModel = .default, fallbackCategorizer: LocalHeuristicSpendingCategorizer = LocalHeuristicSpendingCategorizer()) {
        self.model = model
        self.fallbackCategorizer = fallbackCategorizer
    }

    func categorize(description: String, amount: Decimal) async throws -> SpendingCategory {
        guard model.isAvailable else {
            return try await fallbackCategorizer.categorize(description: description, amount: amount)
        }

        if !Self.safetyModelIsBroken.withLock({ $0 }) {
            do {
                if let category = try await modelCategory(using: model, description: description, amount: amount) {
                    return category
                }
                return try await fallbackCategorizer.categorize(description: description, amount: amount)
            } catch where FoundationModelsFailure.isSafetyModelFailure(error) {
                Self.logger.error("Safety classifier failed; retrying with relaxed guardrails: \(error, privacy: .public)")
                Self.safetyModelIsBroken.withLock { $0 = true }
            }
        }

        do {
            let relaxedModel = SystemLanguageModel(guardrails: .permissiveContentTransformations)
            if let category = try await modelCategory(using: relaxedModel, description: description, amount: amount) {
                return category
            }
        } catch {
            Self.logger.error("Relaxed-guardrails categorization failed: \(error, privacy: .public)")
        }

        return try await fallbackCategorizer.categorize(description: description, amount: amount)
    }

    static let categorizationInstructions = """
    Categorize one personal expense into exactly one of these budget categories:
    \(allowedCategoryNames.joined(separator: ", "))

    Rules:
    - The description is often just a merchant or brand name. Infer what that merchant sells.
    - Use the amount as context. The same merchant can mean different purchases at different prices: a very large amount at a car brand is a vehicle purchase, not office spending.
    - Vehicle purchases, fuel, EV charging, parking, and rideshares are Transport.
    - Prefer the most specific category. Use Misc / Awkward only when nothing fits.
    - Respond with only the category label, nothing else.

    Examples (Amount | Description -> Category):
    6.50 | Blue Bottle -> Food & Drink
    84.12 | Whole Foods -> Groceries
    45 | Shell -> Transport
    12000 | Tesla -> Transport
    15.49 | Netflix -> Subscriptions
    480 | Delta flight to NYC -> Travel
    1199 | new MacBook -> Shopping
    49 | Coursera course -> Work & Education
    2400 | rent -> Housing
    """

    private func modelCategory(using model: SystemLanguageModel, description: String, amount: Decimal) async throws -> SpendingCategory? {
        let session = LanguageModelSession(
            model: model,
            instructions: Self.categorizationInstructions
        )

        let response = try await session.respond(
            to: """
            Amount: \(NSDecimalNumber(decimal: amount).stringValue)
            Description: \(description)
            Return only the single best category label.
            """,
            options: GenerationOptions(temperature: 0.1)
        )

        return Self.category(from: response.content)
    }

    static func availabilitySummary() -> AppleIntelligenceAvailabilitySummary {
        switch SystemLanguageModel.default.availability {
        case .available:
            return AppleIntelligenceAvailabilitySummary(
                title: "Apple Intelligence ready",
                detail: "New expenses are categorized on device with Foundation Models.",
                isAvailable: true
            )
        case .unavailable(.deviceNotEligible):
            return AppleIntelligenceAvailabilitySummary(
                title: "Device not eligible",
                detail: "This iPhone cannot run the on-device Apple Intelligence model. The app will use local keyword rules.",
                isAvailable: false
            )
        case .unavailable(.appleIntelligenceNotEnabled):
            return AppleIntelligenceAvailabilitySummary(
                title: "Apple Intelligence off",
                detail: "Turn on Apple Intelligence in Settings to use Foundation Models. Until then, the app uses local keyword rules.",
                isAvailable: false
            )
        case .unavailable(.modelNotReady):
            return AppleIntelligenceAvailabilitySummary(
                title: "Model not ready",
                detail: "iOS is still preparing or downloading the model. The app will use local keyword rules until it is ready.",
                isAvailable: false
            )
        case .unavailable:
            return AppleIntelligenceAvailabilitySummary(
                title: "Apple Intelligence unavailable",
                detail: "The on-device model is unavailable right now. The app will use local keyword rules.",
                isAvailable: false
            )
        @unknown default:
            return AppleIntelligenceAvailabilitySummary(
                title: "Apple Intelligence status unknown",
                detail: "The app will use local keyword rules if Foundation Models cannot run.",
                isAvailable: false
            )
        }
    }

    static func category(from modelOutput: String) -> SpendingCategory? {
        let trimmed = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = SpendingCategory.category(matching: strippedCategoryDecorations(from: trimmed)) {
            return exact
        }

        let lineCandidates = trimmed
            .components(separatedBy: .newlines)
            .flatMap { line -> [String] in
                let parts = line.components(separatedBy: ":")
                return [line] + parts
            }

        for candidate in lineCandidates {
            if let category = SpendingCategory.category(matching: strippedCategoryDecorations(from: candidate)) {
                return category
            }
        }

        let normalizedOutput = normalizedCategorySearchText(trimmed)
        return SpendingCategory.allCases.first { category in
            normalizedOutput.contains(normalizedCategorySearchText(category.apiName))
        }
    }

    private static func strippedCategoryDecorations(from text: String) -> String {
        text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'`.,;")))
    }

    private static func normalizedCategorySearchText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "/", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct AppleIntelligenceAvailabilitySummary {
    let title: String
    let detail: String
    let isAvailable: Bool
}

struct LocalHeuristicSpendingCategorizer: SpendingCategorizing {
    func categorize(description: String, amount: Decimal) async throws -> SpendingCategory {
        try await Task.sleep(nanoseconds: 350_000_000)
        return Self.category(for: description)
    }

    static func category(for description: String) -> SpendingCategory {
        let text = description.lowercased()

        let rules: [(SpendingCategory, [String])] = [
            (.foodAndDrink, ["coffee", "cafe", "restaurant", "bar", "lunch", "dinner", "breakfast", "pizza", "burger", "doordash", "uber eats"]),
            (.groceries, ["grocery", "groceries", "market", "whole foods", "trader joe", "costco", "safeway"]),
            (.transport, ["uber", "lyft", "taxi", "gas", "parking", "train", "metro", "bus", "toll"]),
            (.housing, ["rent", "mortgage", "hoa", "apartment"]),
            (.utilities, ["electric", "water", "internet", "phone", "utility", "utilities", "wifi"]),
            (.health, ["doctor", "dentist", "pharmacy", "hospital", "therapy", "medicine", "gym"]),
            (.shopping, ["amazon", "target", "clothes", "shoes", "shirt", "pants", "best buy"]),
            (.entertainment, ["movie", "concert", "game", "steam", "spotify", "netflix", "hulu", "ticket"]),
            (.travel, ["flight", "hotel", "airbnb", "rental car", "luggage", "airport"]),
            (.workAndEducation, ["book", "course", "class", "notebook", "software", "workspace", "coworking"]),
            (.subscriptions, ["subscription", "monthly", "annual", "renewal", "saas"]),
            (.giftsAndDonations, ["gift", "donation", "charity", "birthday"]),
            (.feesAndTaxes, ["tax", "fee", "fees", "bank charge", "interest", "irs"])
        ]

        return rules.first { _, keywords in
            keywords.contains { text.contains($0) }
        }?.0 ?? .awkward
    }
}
