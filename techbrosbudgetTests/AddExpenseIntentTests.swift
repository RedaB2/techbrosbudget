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
    @Test func siriAmountRoundsToCents() {
        #expect(SiriExpenseInput.decimalAmount(from: 74) == 74)
        #expect(SiriExpenseInput.decimalAmount(from: 74.125) == 74.13)
        #expect(SiriExpenseInput.decimalAmount(from: 74.124) == 74.12)
    }

    @Test func siriAmountRejectsInvalidValues() {
        #expect(SiriExpenseInput.decimalAmount(from: 0) == nil)
        #expect(SiriExpenseInput.decimalAmount(from: -1) == nil)
        #expect(SiriExpenseInput.decimalAmount(from: .infinity) == nil)
        #expect(SiriExpenseInput.decimalAmount(from: .nan) == nil)
    }

    @Test func siriNoteFallsBackForBlankInput() {
        #expect(SiriExpenseInput.normalizedNote(" coffee ") == "coffee")
        #expect(SiriExpenseInput.normalizedNote("   ") == "Expense")
    }

    @Test func spokenExpenseParsesAmountAndNote() throws {
        let parsedExpense = try #require(SiriExpenseInput.parsedExpense(from: "$74 on coffee"))
        #expect(parsedExpense.amount == 74)
        #expect(parsedExpense.note == "coffee")
    }

    @Test func spokenExpenseHandlesCurrencyWordsAndPrefixes() throws {
        let parsedExpense = try #require(SiriExpenseInput.parsedExpense(from: "I spent 12.345 dollars for lunch"))
        #expect(parsedExpense.amount == 12.35)
        #expect(parsedExpense.note == "lunch")
    }
}
