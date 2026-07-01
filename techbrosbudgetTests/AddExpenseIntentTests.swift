//
//  AddExpenseIntentTests.swift
//  techbrosbudgetTests
//
//  Created by OpenAI on 6/28/26.
//

import Foundation
import Testing
@testable import techbrosbudget

struct AddExpenseIntentTests {
    @Test func spokenAmountRoundsToCents() {
        #expect(SpokenExpenseInput.decimalAmount(from: 74) == 74)
        #expect(SpokenExpenseInput.decimalAmount(from: 74.125) == 74.13)
        #expect(SpokenExpenseInput.decimalAmount(from: 74.124) == 74.12)
    }

    @Test func spokenAmountRejectsInvalidValues() {
        #expect(SpokenExpenseInput.decimalAmount(from: 0) == nil)
        #expect(SpokenExpenseInput.decimalAmount(from: -1) == nil)
        #expect(SpokenExpenseInput.decimalAmount(from: .infinity) == nil)
        #expect(SpokenExpenseInput.decimalAmount(from: .nan) == nil)
    }

    @Test func spokenNoteFallsBackForBlankInput() {
        #expect(SpokenExpenseInput.normalizedNote(" coffee ") == "coffee")
        #expect(SpokenExpenseInput.normalizedNote("   ") == "Expense")
    }

    @Test func spokenExpenseParsesAmountAndNote() throws {
        let parsedExpense = try #require(SpokenExpenseInput.parsedExpense(from: "$74 on coffee"))
        #expect(parsedExpense.amount == 74)
        #expect(parsedExpense.note == "coffee")
    }

    @Test func spokenExpenseHandlesCurrencyWordsAndPrefixes() throws {
        let parsedExpense = try #require(SpokenExpenseInput.parsedExpense(from: "I spent 12.345 dollars for lunch"))
        #expect(parsedExpense.amount == 12.35)
        #expect(parsedExpense.note == "lunch")
    }
}
