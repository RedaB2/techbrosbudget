//
//  BudgetWidgetIntent.swift
//  techbrosbudget
//
//  Created by OpenAI on 6/28/26.
//

import AppIntents

struct BudgetPeriodSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose Amount" }
    static var description: IntentDescription? {
        IntentDescription("Choose whether the small widget shows monthly, weekly, or daily spending.")
    }

    @Parameter(title: "Amount", optionsProvider: BudgetPeriodOptionsProvider())
    var period: String?

    init() {
        period = BudgetPeriodOption.month.rawValue
    }

    init(period: BudgetPeriodOption) {
        self.period = period.rawValue
    }
}

struct BudgetPeriodOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<String> {
        IntentItemCollection {
            IntentItemSection(
                items: BudgetPeriodOption.allCases.map { option in
                    IntentItem(option.rawValue, title: option.title)
                }
            )
        }
    }

    func defaultResult() async -> String? {
        BudgetPeriodOption.month.rawValue
    }
}

enum BudgetPeriodOption: String, CaseIterable, Codable, Sendable {
    case month
    case week
    case day

    var title: LocalizedStringResource {
        switch self {
        case .month:
            return "Monthly"
        case .week:
            return "Weekly"
        case .day:
            return "Daily"
        }
    }

    var budgetPeriod: BudgetPeriod {
        switch self {
        case .month:
            return .month
        case .week:
            return .week
        case .day:
            return .day
        }
    }
}

extension String {
    var budgetWidgetPeriod: BudgetPeriod {
        BudgetPeriodOption(rawValue: self)?.budgetPeriod ?? .month
    }
}
