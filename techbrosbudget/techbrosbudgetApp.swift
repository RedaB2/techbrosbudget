//
//  techbrosbudgetApp.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 6/14/26.
//

import SwiftUI

@main
struct techbrosbudgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(store: launchStore)
        }
    }

    @MainActor
    private var launchStore: BudgetStore? {
        guard ProcessInfo.processInfo.arguments.contains("UITEST_PREVIEW_DATA")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        else {
            return nil
        }

        return .preview
    }
}
