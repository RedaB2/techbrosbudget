//
//  BudgetChatMarkdown.swift
//  techbrosbudget
//

import Foundation

enum BudgetChatMarkdown {
    static func attributedString(from content: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )

        return (try? AttributedString(markdown: content, options: options))
            ?? AttributedString(content)
    }
}
