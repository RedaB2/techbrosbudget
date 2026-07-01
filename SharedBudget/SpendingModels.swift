//
//  SpendingModels.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 6/14/26.
//

import Foundation
import SwiftUI

enum BudgetPeriod: String, CaseIterable, Codable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "Today"
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }

    var detailTitle: String {
        switch self {
        case .day:
            return "Daily spending"
        case .week:
            return "Weekly spending"
        case .month:
            return "Monthly spending"
        }
    }

    var transactionTitle: String {
        switch self {
        case .day:
            return "Day transactions"
        case .week:
            return "Week transactions"
        case .month:
            return "Month transactions"
        }
    }
}

enum SpendingWindowMode: String, CaseIterable, Codable, Identifiable {
    case sliding
    case calendar

    var id: String { rawValue }

    var monthTitle: String {
        switch self {
        case .sliding:
            return "Last 30 days"
        case .calendar:
            return "Calendar month"
        }
    }

    var weekTitle: String {
        switch self {
        case .sliding:
            return "Last 7 days"
        case .calendar:
            return "Calendar week"
        }
    }
}

enum SpendingCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case foodAndDrink = "Food & Drink"
    case groceries = "Groceries"
    case transport = "Transport"
    case housing = "Housing"
    case utilities = "Utilities"
    case health = "Health"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case travel = "Travel"
    case workAndEducation = "Work & Education"
    case subscriptions = "Subscriptions"
    case giftsAndDonations = "Gifts & Donations"
    case feesAndTaxes = "Fees & Taxes"
    case awkward = "Misc / Awkward"

    var id: String { rawValue }

    var apiName: String { rawValue }

    var symbol: String {
        switch self {
        case .foodAndDrink:
            return "fork.knife"
        case .groceries:
            return "cart"
        case .transport:
            return "car"
        case .housing:
            return "house"
        case .utilities:
            return "bolt"
        case .health:
            return "cross.case"
        case .shopping:
            return "bag"
        case .entertainment:
            return "popcorn"
        case .travel:
            return "airplane"
        case .workAndEducation:
            return "laptopcomputer"
        case .subscriptions:
            return "repeat"
        case .giftsAndDonations:
            return "gift"
        case .feesAndTaxes:
            return "doc.text"
        case .awkward:
            return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .foodAndDrink:
            return .orange
        case .groceries:
            return .green
        case .transport:
            return .blue
        case .housing:
            return .brown
        case .utilities:
            return .yellow
        case .health:
            return .red
        case .shopping:
            return .pink
        case .entertainment:
            return .purple
        case .travel:
            return .teal
        case .workAndEducation:
            return .indigo
        case .subscriptions:
            return .cyan
        case .giftsAndDonations:
            return .mint
        case .feesAndTaxes:
            return .gray
        case .awkward:
            return .secondary
        }
    }

    static func category(matching apiName: String) -> SpendingCategory? {
        let normalized = apiName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "/", with: " ")

        return allCases.first { category in
            category.rawValue
                .lowercased()
                .replacingOccurrences(of: "&", with: "and")
                .replacingOccurrences(of: "/", with: " ")
                == normalized
        }
    }
}

enum CategorizationState: String, Codable {
    case pending
    case categorized
    case needsReview
}

struct SpendingComparison: Equatable {
    let currentTotal: Decimal
    let previousTotal: Decimal
    let percentChange: Decimal
    let previousLabel: String

    var isIncrease: Bool {
        percentChange > 0
    }

    var isDecrease: Bool {
        percentChange < 0
    }
}

struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    var amount: Decimal
    var note: String
    var date: Date
    var category: SpendingCategory
    var categorizationState: CategorizationState

    init(
        id: UUID = UUID(),
        amount: Decimal,
        note: String,
        date: Date = Date(),
        category: SpendingCategory = .awkward,
        categorizationState: CategorizationState = .pending
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.date = date
        self.category = category
        self.categorizationState = categorizationState
    }
}

enum MoneyFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = .current
        return formatter
    }()

    static func currency(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? "$0.00"
    }

    static func percentage(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = abs(NSDecimalNumber(decimal: value).doubleValue) < 10 ? 1 : 0
        formatter.minimumFractionDigits = 0

        let number = NSDecimalNumber(decimal: value)
        let formatted = formatter.string(from: number) ?? "0"
        return "\(value >= 0 ? "+" : "")\(formatted)%"
    }
}

enum MoneyParser {
    static func decimal(from input: String) -> Decimal? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let allowedCharacters = CharacterSet(charactersIn: "0123456789.,")
        let cleaned = String(trimmed.unicodeScalars.filter { allowedCharacters.contains($0) })
            .replacingOccurrences(of: ",", with: "")

        guard !cleaned.isEmpty else {
            return nil
        }

        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
}
