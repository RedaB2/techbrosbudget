//
//  AutoCaptureSetupView.swift
//  techbrosbudget
//
//  Created by Claude on 7/11/26.
//

import SwiftUI

/// Walks the user through wiring the Shortcuts automations that feed
/// auto-capture. Apple doesn't let apps install automations programmatically,
/// so clear manual steps are the whole feature here.
struct AutoCaptureSetupView: View {
    @Environment(\.openURL) private var openURL

    private var isNotificationTriggerAvailable: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
    }

    var body: some View {
        ZStack {
            BudgetBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Pay with your card, and the expense logs and categorizes itself — no app launch, no typing. iOS requires you to switch this on yourself in the Shortcuts app; it takes about a minute.")
                        .font(.system(size: 13))
                        .foregroundStyle(Monolith.secondary)

                    MonolithDivider()
                        .padding(.vertical, 26)

                    MonolithLabel("Apple Pay Taps")
                        .padding(.bottom, 6)

                    Text("Works on iOS 26 and later. Logs every tap-to-pay purchase silently.")
                        .font(.system(size: 12))
                        .foregroundStyle(Monolith.tertiary)
                        .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 14) {
                        SetupStepRow(number: 1, text: "Open the Shortcuts app and go to the Automation tab.")
                        SetupStepRow(number: 2, text: "Tap + and choose the Wallet trigger.")
                        SetupStepRow(number: 3, text: "Select the cards to track and choose Run Immediately.")
                        SetupStepRow(number: 4, text: "Add the “Log Wallet Transaction” action from Tech Bros Budget, then pass the transaction's Amount and Merchant into it.")
                    }

                    MonolithDivider()
                        .padding(.vertical, 26)

                    HStack(spacing: 8) {
                        MonolithLabel("Every Card Purchase")

                        if !isNotificationTriggerAvailable {
                            Text("REQUIRES iOS 27")
                                .font(.system(size: 9, weight: .semibold))
                                .kerning(1.2)
                                .foregroundStyle(Monolith.tertiary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .overlay(
                                    Capsule().strokeBorder(Monolith.hairline)
                                )
                        }
                    }
                    .padding(.bottom, 6)

                    Text("Works on iOS 27 and later. Reads your bank's purchase notifications, so card swipes and online checkouts are captured too — not just Apple Pay.")
                        .font(.system(size: 12))
                        .foregroundStyle(Monolith.tertiary)
                        .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 14) {
                        SetupStepRow(number: 1, text: "In your banking app, turn on instant purchase notifications.")
                        SetupStepRow(number: 2, text: "In Shortcuts, tap + in the Automation tab and choose the Notification trigger, then select your banking app or Wallet.")
                        SetupStepRow(number: 3, text: "Choose Run Immediately.")
                        SetupStepRow(number: 4, text: "Add the “Log Transaction Notification” action from Tech Bros Budget, then pass the notification's Title and Body into it.")
                    }

                    Text("iOS shows a brief “automation ran” banner for notification triggers — that's an Apple safety rule, and it means it's working. If a purchase is caught twice (an Apple Pay tap plus the bank's notification), the duplicate is skipped automatically.")
                        .font(.system(size: 12))
                        .foregroundStyle(Monolith.tertiary)
                        .padding(.top, 16)

                    MonolithDivider()
                        .padding(.vertical, 26)

                    Button {
                        if let url = URL(string: "shortcuts://") {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 13, weight: .medium))
                            Text("Open Shortcuts")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(Monolith.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Monolith.hairline)
                        )
                    }
                    .buttonStyle(.plain)

                    Text("Auto-captured expenses show a bolt in your history. Amounts and merchant names never leave your device.")
                        .font(.system(size: 12))
                        .foregroundStyle(Monolith.tertiary)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Auto-Capture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct SetupStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Monolith.secondary)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().strokeBorder(Monolith.hairline)
                )

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Monolith.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number). \(text)")
    }
}

#Preview {
    NavigationStack {
        AutoCaptureSetupView()
    }
}
