//
//  OnboardingView.swift
//  techbrosbudget
//

import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            BudgetBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                Image("BrandLogoForeground")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .accessibilityLabel("Tech Bros logo")

                MonolithLabel("TechBros Budget", size: 11)
                    .padding(.top, 18)

                Text("Three numbers.\nZero friction.")
                    .font(.system(size: 34, weight: .ultraLight))
                    .foregroundStyle(Monolith.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)

                VStack(alignment: .leading, spacing: 0) {
                    OnboardingFeatureRow(
                        icon: "plus.forwardslash.minus",
                        title: "Log spending in seconds",
                        subtitle: "Type an amount and a note. Totals update immediately."
                    )

                    MonolithDivider()

                    OnboardingFeatureRow(
                        icon: "sparkles",
                        title: "Categories sort themselves",
                        subtitle: "Apple Intelligence categorizes expenses on device, in the background."
                    )

                    MonolithDivider()

                    OnboardingFeatureRow(
                        icon: "calendar",
                        title: "Day, week, and month at a glance",
                        subtitle: "Compare each window with the previous one to spot trends."
                    )
                }
                .padding(.top, 30)
                .padding(.horizontal, 32)

                Spacer(minLength: 24)

                Button(action: onContinue) {
                    Text("Continue")
                }
                .buttonStyle(MonolithBlockButtonStyle())
                .accessibilityIdentifier("Continue")
                .accessibilityLabel("Continue")
                .padding(.horizontal, 28)

                Text("Private by design: your data stays in your personal iCloud.")
                    .font(.system(size: 12))
                    .foregroundStyle(Monolith.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.horizontal, 36)
            }
            .padding(.bottom, 16)
        }
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Monolith.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Monolith.primary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Monolith.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 15)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView {}
}
