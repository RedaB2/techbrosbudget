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
                    .frame(width: 150, height: 150)
                    .accessibilityLabel("Tech Bros logo")

                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(
                        icon: "plus.forwardslash.minus",
                        tint: .mint,
                        title: "Log spending in seconds",
                        subtitle: "Type an amount and a note. Totals update immediately."
                    )

                    FeatureRow(
                        icon: "sparkles",
                        tint: .indigo,
                        title: "Categories sort themselves",
                        subtitle: "Apple Intelligence categorizes expenses on device, in the background."
                    )

                    FeatureRow(
                        icon: "calendar",
                        tint: .orange,
                        title: "Day, week, and month at a glance",
                        subtitle: "Compare each window with the previous one to spot trends."
                    )
                }
                .padding(.top, 36)
                .padding(.horizontal, 32)

                Spacer(minLength: 24)

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("Continue")
                .padding(.horizontal, 24)

                Text("Private by design: your data stays in your personal iCloud.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.horizontal, 36)
            }
            .padding(.bottom, 16)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(tint.gradient, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView {}
}
