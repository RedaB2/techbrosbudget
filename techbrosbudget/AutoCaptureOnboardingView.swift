//
//  AutoCaptureOnboardingView.swift
//  techbrosbudget
//
//  Created by Claude on 7/14/26.
//
//  The auto-capture "babysitter": a full-screen guided flow that pops once
//  for anyone not yet capturing, pitches the feature in one line, walks the
//  Shortcuts setup tap by tap, and flips to "it's working" on its own when
//  the first capture lands. Apple doesn't let apps install automations
//  programmatically, so hand-holding the manual step is the whole game.
//

import SwiftUI

// MARK: - Enrollment state

/// Tracks whether this device has ever auto-captured an expense and whether
/// the launch intro was already shown. Kept as plain functions over
/// UserDefaults so the gate logic is unit-testable.
enum AutoCaptureEnrollment {
    static let introSeenDefaultsKey = "hasSeenAutoCaptureIntro"
    static let firstCaptureDefaultsKey = "autoCaptureFirstCaptureAt"

    /// Called by the capture intents; remembers the first success forever so
    /// the intro never nags a user whose automation is already firing.
    static func markCaptured(in defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: firstCaptureDefaultsKey) == nil else {
            return
        }

        defaults.set(Date(), forKey: firstCaptureDefaultsKey)
    }

    static func hasEverCaptured(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: firstCaptureDefaultsKey) != nil
    }

    /// The launch popup shows exactly once, and only to users who aren't
    /// already capturing. Dismissing it counts as seen — Settings keeps a
    /// permanent way back in.
    static func shouldPresentIntro(hasSeenIntro: Bool, isCapturing: Bool) -> Bool {
        !hasSeenIntro && !isCapturing
    }
}

// MARK: - Wizard

struct AutoCaptureOnboardingView: View {
    @ObservedObject var store: BudgetStore
    /// Marks the intro as seen and dismisses, whatever page it's called from.
    let onComplete: () -> Void

    @Environment(\.openURL) private var openURL
    @AppStorage(AppearanceSetting.storageKey) private var appearanceRawValue = AppearanceSetting.system.rawValue
    @State private var stage = Stage.pitch
    @State private var completedNotificationSteps = false

    private enum Stage {
        case pitch
        case walletSteps
        case notificationSteps
        case finish
    }

    private var isNotificationTriggerAvailable: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
    }

    private var isCapturing: Bool {
        store.hasAutoCapturedExpenses || AutoCaptureEnrollment.hasEverCaptured()
    }

    var body: some View {
        ZStack {
            BudgetBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    MonolithIconButton(systemName: "xmark", diameter: 36, iconSize: 12) {
                        onComplete()
                    }
                    .accessibilityLabel("Close auto-capture setup")
                    .accessibilityIdentifier("AutoCaptureClose")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                switch stage {
                case .pitch:
                    pitchPage
                        .transition(pageTransition)
                case .walletSteps:
                    stepsPage(
                        label: "One-Minute Setup",
                        title: "Four taps\nin Shortcuts.",
                        steps: Self.walletSteps,
                        footnote: "If Shortcuts asks what to log, pick the transaction's Amount and Merchant."
                    )
                    .transition(pageTransition)
                case .notificationSteps:
                    stepsPage(
                        label: "Level Up",
                        title: "Catch every\ncard purchase.",
                        steps: Self.notificationSteps,
                        footnote: "Needs purchase alerts turned on in your bank's app. iOS flashes a brief banner each time — that means it's working."
                    )
                    .transition(pageTransition)
                case .finish:
                    finishPage
                        .transition(pageTransition)
                }
            }
        }
        .preferredColorScheme(appearanceSetting.preferredColorScheme)
    }

    private var appearanceSetting: AppearanceSetting {
        AppearanceSetting(rawValue: appearanceRawValue) ?? .system
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance(to next: Stage) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            stage = next
        }
    }

    // MARK: Pitch

    private var pitchPage: some View {
        VStack(spacing: 0) {
            Spacer()

            boltGlyph(filled: false, pulsing: true)

            MonolithLabel("Auto-Capture")
                .padding(.top, 28)

            Text("Pay.\nIt logs itself.")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Monolith.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)

            Text("Every card purchase becomes an expense on its own — no app launch, no typing.")
                .font(.system(size: 13))
                .foregroundStyle(Monolith.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .padding(.horizontal, 48)

            Text("One minute to switch on. We'll walk you through every tap.")
                .font(.system(size: 12))
                .foregroundStyle(Monolith.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .padding(.horizontal, 48)

            Spacer()

            Button {
                advance(to: .walletSteps)
            } label: {
                Text("Set It Up")
            }
            .buttonStyle(MonolithBlockButtonStyle())
            .accessibilityIdentifier("AutoCaptureSetItUp")
            .padding(.horizontal, 28)

            Button {
                onComplete()
            } label: {
                Text("Maybe Later")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Monolith.tertiary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("AutoCaptureMaybeLater")
            .padding(.top, 8)
        }
        .padding(.bottom, 20)
    }

    // MARK: Steps

    private static let walletSteps: [GuidedStep] = [
        GuidedStep(number: 1, instruction: "Open Shortcuts and tap", chipIcon: "clock.arrow.2.circlepath", chipText: "Automation"),
        GuidedStep(number: 2, instruction: "Tap + and choose the trigger", chipIcon: "creditcard", chipText: "Transaction"),
        GuidedStep(number: 3, instruction: "Pick your cards, then select", chipIcon: nil, chipText: "Run Immediately"),
        GuidedStep(number: 4, instruction: "Search Tech Bros and add", chipIcon: "bolt.fill", chipText: "Log Wallet Transaction")
    ]

    private static let notificationSteps: [GuidedStep] = [
        GuidedStep(number: 1, instruction: "Open Shortcuts and tap", chipIcon: "clock.arrow.2.circlepath", chipText: "Automation"),
        GuidedStep(number: 2, instruction: "Tap + and choose the trigger", chipIcon: "bell.badge", chipText: "Notification"),
        GuidedStep(number: 3, instruction: "Pick Wallet or your bank's app, then select", chipIcon: nil, chipText: "Run Immediately"),
        GuidedStep(number: 4, instruction: "Search Tech Bros and add", chipIcon: "bolt.fill", chipText: "Log Transaction Notification")
    ]

    private func stepsPage(label: String, title: String, steps: [GuidedStep], footnote: String) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonolithLabel(label)

                    Text(title)
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundStyle(Monolith.primary)
                        .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(steps) { step in
                            GuidedStepRow(step: step)
                        }
                    }
                    .padding(.top, 30)

                    Text(footnote)
                        .font(.system(size: 12))
                        .foregroundStyle(Monolith.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 26)
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                if let url = URL(string: "shortcuts://") {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 13, weight: .medium))
                    Text("Open Shortcuts")
                }
            }
            .buttonStyle(MonolithBlockButtonStyle())
            .accessibilityIdentifier("AutoCaptureOpenShortcuts")
            .padding(.horizontal, 28)

            Button {
                if stage == .notificationSteps {
                    completedNotificationSteps = true
                }
                advance(to: .finish)
            } label: {
                Text("I've added it")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Monolith.secondary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("AutoCaptureStepsDone")
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    // MARK: Finish

    private var finishPage: some View {
        VStack(spacing: 0) {
            Spacer()

            boltGlyph(filled: isCapturing, pulsing: !isCapturing)

            MonolithLabel(isCapturing ? "Active" : "Setup Complete")
                .padding(.top, 28)

            Text(isCapturing ? "It's working." : "Your next purchase\nlogs itself.")
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(Monolith.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)

            Text(isCapturing
                ? "Purchases are logging themselves — spot them by the bolt in Recent."
                : "Tap to pay and watch it appear — marked with a bolt.")
                .font(.system(size: 13))
                .foregroundStyle(Monolith.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .padding(.horizontal, 48)

            if isNotificationTriggerAvailable && !completedNotificationSteps {
                Button {
                    advance(to: .notificationSteps)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 13, weight: .light))

                        Text("Also catch online and chip purchases")
                            .font(.system(size: 13, weight: .medium))

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Monolith.tertiary)
                    }
                    .foregroundStyle(Monolith.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Monolith.hairline)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("AutoCaptureNotificationBoost")
                .padding(.top, 28)
                .padding(.horizontal, 28)
            }

            Spacer()

            Button {
                onComplete()
            } label: {
                Text("Done")
            }
            .buttonStyle(MonolithBlockButtonStyle())
            .accessibilityIdentifier("AutoCaptureDone")
            .padding(.horizontal, 28)
        }
        .padding(.bottom, 20)
    }

    // MARK: Shared glyph

    private func boltGlyph(filled: Bool, pulsing: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(Monolith.ring, lineWidth: 1)
                .frame(width: 96, height: 96)

            Image(systemName: filled ? "bolt.fill" : "bolt")
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(Monolith.primary)
                .symbolEffect(.pulse, isActive: pulsing)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Step row

private struct GuidedStep: Identifiable {
    let number: Int
    let instruction: String
    let chipIcon: String?
    let chipText: String

    var id: Int { number }
}

/// One instruction plus a "chip" showing the exact label to look for in the
/// Shortcuts app, so the user matches text instead of parsing prose.
private struct GuidedStepRow: View {
    let step: GuidedStep

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(step.number)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Monolith.secondary)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle().strokeBorder(Monolith.hairline)
                )

            VStack(alignment: .leading, spacing: 9) {
                Text(step.instruction)
                    .font(.system(size: 14))
                    .foregroundStyle(Monolith.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)

                HStack(spacing: 6) {
                    if let icon = step.chipIcon {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .medium))
                            .accessibilityHidden(true)
                    }

                    Text(step.chipText)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Monolith.primary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Monolith.ring)
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.number). \(step.instruction) \(step.chipText)")
    }
}

#Preview {
    AutoCaptureOnboardingView(store: .preview) {}
}
