//
//  techbrosbudgetApp.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 6/14/26.
//

import SwiftUI

private func hasDebugLaunchArgument(_ argument: String) -> Bool {
    #if DEBUG
    ProcessInfo.processInfo.arguments.contains(argument)
    #else
    false
    #endif
}

private func isDebugXCTestRun() -> Bool {
    #if DEBUG
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    #else
    false
    #endif
}

@main
struct techbrosbudgetApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(launchStore: launchStore, skipsOnboarding: isAutomatedRun)
        }
    }

    private var isAutomatedRun: Bool {
        hasDebugLaunchArgument("UITEST_PREVIEW_DATA") || isDebugXCTestRun()
    }

    @MainActor
    private var launchStore: BudgetStore? {
        guard isAutomatedRun else {
            return nil
        }

        return .preview
    }
}

private struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppearanceSetting.storageKey) private var appearanceRawValue = AppearanceSetting.system.rawValue
    @State private var forcesOnboarding = hasDebugLaunchArgument("UITEST_SHOW_ONBOARDING")
    let launchStore: BudgetStore?
    let skipsOnboarding: Bool

    private var showsOnboarding: Bool {
        forcesOnboarding || (!hasCompletedOnboarding && !skipsOnboarding)
    }

    var body: some View {
        ZStack {
            if showsOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                    forcesOnboarding = false
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                // Automated runs skip the auto-capture popup too, unless a UI
                // test opts in with UITEST_SHOW_AUTOCAPTURE_INTRO.
                ContentView(store: launchStore, autoCaptureIntroEnabled: !skipsOnboarding)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showsOnboarding)
        .preferredColorScheme(appearanceSetting.preferredColorScheme)
    }

    private var appearanceSetting: AppearanceSetting {
        AppearanceSetting(rawValue: appearanceRawValue) ?? .system
    }
}
