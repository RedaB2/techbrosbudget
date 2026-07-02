//
//  FoundationModelsFailure.swift
//  techbrosbudget
//

import Foundation
import FoundationModels

enum FoundationModelsFailure {
    /// On some iOS 26 builds the system safety classifier
    /// (`com.apple.fm.language.instruct_300m.safety`, run through
    /// SensitiveContentAnalysisML) fails to load, and every generation request
    /// throws even though the language model itself works and reports
    /// available. That failure surfaces as an untyped NSError chain rather
    /// than a `GenerationError` case, so it has to be detected by walking the
    /// underlying error domains.
    ///
    /// Returns `true` only for that infrastructure failure — never for a
    /// genuine guardrail content violation.
    static func isSafetyModelFailure(_ error: any Error) -> Bool {
        if let generationError = error as? LanguageModelSession.GenerationError,
           case .guardrailViolation = generationError {
            return false
        }

        var pending: [NSError] = [error as NSError]
        var inspected = 0
        while let nsError = pending.popLast(), inspected < 32 {
            inspected += 1
            if nsError.domain == "com.apple.SensitiveContentAnalysisML"
                || nsError.domain.hasPrefix("ModelManagerServices") {
                return true
            }
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                pending.append(underlying)
            }
            if let multiple = nsError.userInfo[NSMultipleUnderlyingErrorsKey] as? [NSError] {
                pending.append(contentsOf: multiple)
            }
        }
        return false
    }
}
