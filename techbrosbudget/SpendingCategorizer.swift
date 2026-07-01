//
//  SpendingCategorizer.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 6/14/26.
//

import Foundation
import FoundationModels

protocol SpendingCategorizing {
    func categorize(description: String, amount: Decimal) async throws -> SpendingCategory
}

struct AppleIntelligenceSpendingCategorizer: SpendingCategorizing {
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

        let session = LanguageModelSession(
            model: model,
            instructions: """
            Categorize one personal expense into exactly one of the allowed budget categories.
            Prefer the most specific category. Use Misc / Awkward only when no category fits.
            """
        )

        let response = try await session.respond(
            to: """
            Amount: \(NSDecimalNumber(decimal: amount).stringValue)
            Description: \(description)
            Allowed categories: \(ExpenseCategoryResult.allowedCategories.joined(separator: ", "))
            """,
            generating: ExpenseCategoryResult.self,
            options: GenerationOptions(temperature: 0.1)
        )

        return SpendingCategory.category(matching: response.content.category) ?? .awkward
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

    @Generable
    struct ExpenseCategoryResult {
        static let allowedCategories = SpendingCategory.allCases.map(\.apiName)

        @Guide(description: "The best matching budget category.", .anyOf(Self.allowedCategories))
        var category: String

        @Guide(description: "Confidence from 0.0 to 1.0.", .range(0.0...1.0))
        var confidence: Double
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
