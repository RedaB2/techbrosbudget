//
//  FoundationModelsFailureTests.swift
//  techbrosbudgetTests
//

import Foundation
import Testing
@testable import techbrosbudget

struct FoundationModelsFailureTests {
    /// Mirrors the error chain thrown on iOS 26.5 when the system safety
    /// classifier fails to load: FoundationModels wraps the failure in
    /// NSMultipleUnderlyingErrorsKey, with SensitiveContentAnalysisML and
    /// ModelManagerServices errors nested inside.
    @Test func detectsBrokenSafetyClassifierChain() {
        let modelManagerError = NSError(
            domain: "ModelManagerServices.ModelManagerError",
            code: 1001
        )
        let sensitiveContentError = NSError(
            domain: "com.apple.SensitiveContentAnalysisML",
            code: 15,
            userInfo: [NSMultipleUnderlyingErrorsKey: [modelManagerError]]
        )
        let generationError = NSError(
            domain: "FoundationModels.LanguageModelSession.GenerationError",
            code: -1,
            userInfo: [NSMultipleUnderlyingErrorsKey: [sensitiveContentError]]
        )
        let wrapper = NSError(
            domain: "FoundationModels.LanguageModelSession.GenerationError",
            code: -1,
            userInfo: [NSMultipleUnderlyingErrorsKey: [generationError]]
        )

        #expect(FoundationModelsFailure.isSafetyModelFailure(wrapper))
    }

    @Test func detectsSensitiveContentErrorViaSingleUnderlyingError() {
        let sensitiveContentError = NSError(domain: "com.apple.SensitiveContentAnalysisML", code: 15)
        let wrapper = NSError(
            domain: "FoundationModels.LanguageModelSession.GenerationError",
            code: -1,
            userInfo: [NSUnderlyingErrorKey: sensitiveContentError]
        )

        #expect(FoundationModelsFailure.isSafetyModelFailure(wrapper))
    }

    @Test func ignoresUnrelatedErrors() {
        let plain = NSError(domain: "NSCocoaErrorDomain", code: 4)
        #expect(!FoundationModelsFailure.isSafetyModelFailure(plain))

        let unrelatedNested = NSError(
            domain: "FoundationModels.LanguageModelSession.GenerationError",
            code: -1,
            userInfo: [NSUnderlyingErrorKey: NSError(domain: "NSURLErrorDomain", code: -1009)]
        )
        #expect(!FoundationModelsFailure.isSafetyModelFailure(unrelatedNested))
    }

    @Test func survivesCyclicOrDeepErrorChains() {
        var deepest = NSError(domain: "SomeDomain", code: 1)
        for i in 0..<100 {
            deepest = NSError(
                domain: "WrapperDomain\(i)",
                code: i,
                userInfo: [NSUnderlyingErrorKey: deepest]
            )
        }
        #expect(!FoundationModelsFailure.isSafetyModelFailure(deepest))
    }
}
