//
//  MonolithStyle.swift
//  techbrosbudget
//
//  The Monolith design language: pure black (dark) / paper white (light),
//  ultra-light tabular numerals, hairline dividers, micro-tracked uppercase
//  labels, thin-ring controls, and a single accent reserved for spend trends.
//

import SwiftUI
import UIKit

// MARK: - Palette

enum Monolith {
    /// Pure black in dark mode; warm paper white in light mode.
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : UIColor(white: 0.975, alpha: 1)
    })

    static let primary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : UIColor(white: 0.08, alpha: 1)
    })

    static let secondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.46)
            : UIColor(white: 0.08, alpha: 0.52)
    })

    static let tertiary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.26)
            : UIColor(white: 0.08, alpha: 0.30)
    })

    static let hairline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 0, alpha: 0.10)
    })

    /// Ring strokes for circular controls: brighter than a hairline, dimmer than text.
    static let ring = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.22)
            : UIColor(white: 0, alpha: 0.24)
    })

    /// Spending went down — the only celebratory color in the system.
    static let positive = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1)
            : UIColor(red: 0.02, green: 0.55, blue: 0.36, alpha: 1)
    })

    /// Spending went up.
    static let negative = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.44, blue: 0.52, alpha: 1)
            : UIColor(red: 0.78, green: 0.19, blue: 0.30, alpha: 1)
    })
}

// MARK: - Background

/// Solid Monolith canvas. Kept under its historical name so every screen
/// that referenced the old gradient background picks up the new language.
struct BudgetBackground: View {
    var body: some View {
        Monolith.background.ignoresSafeArea()
    }
}

// MARK: - Micro label

/// Uppercase, letter-spaced micro label. The accessibility label keeps the
/// original casing so VoiceOver (and UI tests) read natural words.
struct MonolithLabel: View {
    let text: String
    var size: CGFloat = 10
    var color: Color = Monolith.secondary

    init(_ text: String, size: CGFloat = 10, color: Color = Monolith.secondary) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .semibold))
            .kerning(size * 0.32)
            .foregroundStyle(color)
            .lineLimit(1)
            .accessibilityLabel(Text(text))
    }
}

// MARK: - Hairline divider

struct MonolithDivider: View {
    var body: some View {
        Rectangle()
            .fill(Monolith.hairline)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - Amount text

extension MoneyFormatter {
    /// Splits a formatted currency string into whole and fractional parts so
    /// the fraction can render dimmed ("$2,184" + ".03").
    static func currencyParts(_ amount: Decimal) -> (whole: String, fraction: String) {
        let full = currency(amount)
        let separator = Locale.current.decimalSeparator ?? "."

        guard let range = full.range(of: separator, options: .backwards) else {
            return (full, "")
        }

        return (String(full[..<range.lowerBound]), String(full[range.lowerBound...]))
    }
}

/// The big Monolith numeral: ultra-light, tabular, dimmed cents. Rolls its
/// digits when the value changes; optionally counts up from zero on first
/// appearance (the mockup's count-up animation).
struct MonolithAmountText: View {
    let amount: Decimal
    var size: CGFloat = 40
    var countsUpOnAppear = false

    @State private var displayed: Decimal
    @State private var hasAppeared = false

    init(amount: Decimal, size: CGFloat = 40, countsUpOnAppear: Bool = false) {
        self.amount = amount
        self.size = size
        self.countsUpOnAppear = countsUpOnAppear
        _displayed = State(initialValue: countsUpOnAppear ? 0 : amount)
    }

    var body: some View {
        let parts = MoneyFormatter.currencyParts(displayed)
        let animationValue = NSDecimalNumber(decimal: displayed).doubleValue

        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.whole)
                .foregroundStyle(Monolith.primary)
                .contentTransition(.numericText(value: animationValue))

            Text(parts.fraction)
                .foregroundStyle(Monolith.tertiary)
                .contentTransition(.numericText(value: animationValue))
        }
        .font(.system(size: size, weight: .ultraLight).monospacedDigit())
        .tracking(-size * 0.015)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityLabel(MoneyFormatter.currency(amount))
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true

            if countsUpOnAppear {
                withAnimation(.easeOut(duration: 0.9)) {
                    displayed = amount
                }
            }
        }
        .onChange(of: amount) { _, newValue in
            withAnimation(.snappy(duration: 0.5)) {
                displayed = newValue
            }
        }
    }
}

// MARK: - Delta line

/// "▼ 25% vs yesterday · $63.10" — the trend readout under an expanded number.
struct MonolithDeltaLine: View {
    let comparison: SpendingComparison

    private var color: Color {
        if comparison.isIncrease { return Monolith.negative }
        if comparison.isDecrease { return Monolith.positive }
        return Monolith.secondary
    }

    private var arrow: String {
        if comparison.isIncrease { return "▲" }
        if comparison.isDecrease { return "▼" }
        return "—"
    }

    private var magnitude: String {
        let text = MoneyFormatter.percentage(abs(comparison.percentChange))
        return text.hasPrefix("+") ? String(text.dropFirst()) : text
    }

    var body: some View {
        Group {
            if comparison.percentChange == 0 {
                Text("— even vs \(comparison.previousLabel) · \(MoneyFormatter.currency(comparison.previousTotal))")
            } else {
                Text("\(arrow) \(magnitude) vs \(comparison.previousLabel) · \(MoneyFormatter.currency(comparison.previousTotal))")
            }
        }
        .font(.system(size: 12, weight: .medium).monospacedDigit())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

// MARK: - Sparkline

/// Hairline trend polyline with an accent dot on the latest value.
struct Sparkline: View {
    let values: [Double]
    var accent: Color = Monolith.tertiary

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)

            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        Monolith.primary.opacity(0.24),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                }

                if let last = points.last {
                    Circle()
                        .fill(accent)
                        .frame(width: 5, height: 5)
                        .position(last)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else {
            return values.isEmpty ? [] : [CGPoint(x: size.width - 3, y: size.height / 2)]
        }

        let inset: CGFloat = 3
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let range = maxValue - minValue
        let stepX = (size.width - inset * 2) / CGFloat(values.count - 1)

        return values.enumerated().map { index, value in
            let fraction = range > 0 ? (value - minValue) / range : 0.5
            return CGPoint(
                x: inset + CGFloat(index) * stepX,
                y: inset + (1 - CGFloat(fraction)) * (size.height - inset * 2)
            )
        }
    }
}

// MARK: - Text tabs

/// Minimal typographic segmented control: uppercase labels with a sliding
/// underline. Replaces glassy segmented pickers throughout.
struct MonolithTextTabs<Option: Hashable>: View {
    let options: [(value: Option, title: String)]
    @Binding var selection: Option

    @Namespace private var underline

    var body: some View {
        HStack(spacing: 20) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection

                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        selection = option.value
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(option.title.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(2.6)
                            .foregroundStyle(isSelected ? Monolith.primary : Monolith.tertiary)

                        ZStack {
                            Rectangle()
                                .fill(.clear)
                                .frame(height: 1.5)

                            if isSelected {
                                Rectangle()
                                    .fill(Monolith.primary)
                                    .frame(height: 1.5)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                    }
                    .fixedSize()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Buttons

/// Thin-ring circular button chrome (the Monolith "+" and icon buttons).
struct MonolithRingButtonStyle: ButtonStyle {
    var diameter: CGFloat = 64

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: diameter, height: diameter)
            .background(Monolith.background.opacity(0.88), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(
                        configuration.isPressed ? Monolith.secondary : Monolith.ring,
                        lineWidth: 1
                    )
            }
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Small ring icon button (settings gear, chat close, mic).
struct MonolithIconButton: View {
    let systemName: String
    var diameter: CGFloat = 40
    var iconSize: CGFloat = 14
    var tint: Color = Monolith.secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(tint)
        }
        .buttonStyle(MonolithRingButtonStyle(diameter: diameter))
    }
}

/// Full-width inverse block button — the single primary action on a screen.
struct MonolithBlockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .kerning(3.6)
            .textCase(.uppercase)
            .foregroundStyle(Monolith.background)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Monolith.primary)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Empty state

struct MonolithEmptyRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Monolith.tertiary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Monolith.secondary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Monolith.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}
