//
//  VaultView.swift
//  techbrosbudget
//
//  The Vault: a shelf of minted monoliths — one slab per logging feat — plus
//  the running record of how faithfully expenses have been logged. Lives to
//  the left of the home screen, behind a left-to-right swipe.
//

import SwiftUI

struct VaultView: View {
    @ObservedObject var store: BudgetStore
    let onClose: () -> Void

    @State private var selectedFeatID: String?

    private var ledger: VaultLedger {
        VaultLedger(expenses: store.expenses)
    }

    var body: some View {
        ZStack {
            BudgetBackground()

            ScrollView {
                let ledger = self.ledger

                VStack(alignment: .leading, spacing: 0) {
                    header

                    MonolithLabel("Days recorded")
                        .padding(.top, 34)

                    Text("\(ledger.daysRecorded)")
                        .font(.system(size: 60, weight: .ultraLight).monospacedDigit())
                        .foregroundStyle(Monolith.primary)
                        .padding(.top, 8)
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(ledger.daysRecorded) days recorded")

                    statLine(for: ledger)
                        .padding(.top, 6)

                    MonolithDivider()
                        .padding(.vertical, 26)

                    HStack {
                        MonolithLabel("Minted")

                        Spacer()

                        Text("\(ledger.feats.filter(\.isMinted).count)")
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Monolith.tertiary)
                    }

                    shelf(for: ledger)
                        .padding(.top, 22)

                    plaque(for: ledger)
                        .padding(.top, 16)

                    MonolithDivider()
                        .padding(.vertical, 26)

                    MonolithLabel("This week")

                    weekRow(for: ledger)
                        .padding(.top, 14)

                    Text(weekCaption(for: ledger))
                        .font(.system(size: 12))
                        .foregroundStyle(Monolith.tertiary)
                        .padding(.top, 12)
                        .fixedSize(horizontal: false, vertical: true)

                    if let next = ledger.nextMilestone {
                        MonolithDivider()
                            .padding(.vertical, 26)

                        HStack(alignment: .firstTextBaseline) {
                            MonolithLabel("Next milestone")

                            Spacer()

                            Text("\(next.title) · \(next.count) logged")
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundStyle(Monolith.secondary)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if selectedFeatID == nil {
                selectedFeatID = ledger.latestMintedFeat?.id
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedFeatID)
    }

    private var header: some View {
        HStack {
            MonolithLabel("The Vault", size: 11, color: Monolith.primary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            MonolithIconButton(systemName: "arrow.right", diameter: 36, action: onClose)
                .accessibilityLabel("Back to budget")
        }
    }

    private func statLine(for ledger: VaultLedger) -> some View {
        Text("\(ledger.totalLogged) logged · \(ledger.perfectWeekCount) perfect \(ledger.perfectWeekCount == 1 ? "week" : "weeks")")
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .foregroundStyle(Monolith.secondary)
    }

    // MARK: - Shelf

    private func shelf(for ledger: VaultLedger) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(ledger.feats) { feat in
                    slab(for: feat)
                }
            }
            .padding(.horizontal, 2)
            .frame(minHeight: 130, alignment: .bottom)
        }
        .overlay(alignment: .bottom) {
            MonolithDivider()
        }
        .accessibilityLabel("Shelf of minted monoliths")
    }

    private func slab(for feat: VaultFeat) -> some View {
        let isSelected = selectedFeatID == feat.id

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedFeatID = feat.id
            }
        } label: {
            Group {
                if feat.isMinted {
                    Rectangle()
                        .fill(Monolith.primary)
                } else {
                    Rectangle()
                        .strokeBorder(Monolith.ring, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .frame(width: 26, height: feat.height)
            .offset(y: isSelected ? -6 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(feat.title). \(feat.detail)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func plaque(for ledger: VaultLedger) -> some View {
        let feat = ledger.feats.first { $0.id == selectedFeatID } ?? ledger.latestMintedFeat

        return VStack(alignment: .leading, spacing: 6) {
            if let feat {
                MonolithLabel(feat.title, size: 9)

                Text(feat.detail)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Monolith.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                MonolithLabel("Nothing minted", size: 9)

                Text("Log your first expense to mint the Genesis monolith.")
                    .font(.system(size: 12))
                    .foregroundStyle(Monolith.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: 44, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Current week

    private func weekRow(for ledger: VaultLedger) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                let isRecorded = index < ledger.currentWeekDayFlags.count && ledger.currentWeekDayFlags[index]

                VStack(spacing: 7) {
                    Group {
                        if isRecorded {
                            Rectangle().fill(Monolith.primary)
                        } else {
                            Rectangle().strokeBorder(Monolith.hairline, lineWidth: 1)
                        }
                    }
                    .frame(width: 20, height: 20)

                    Text(symbol.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(Monolith.tertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(symbol): \(isRecorded ? "recorded" : "not recorded")")
            }
        }
    }

    private func weekCaption(for ledger: VaultLedger) -> String {
        let days = ledger.currentWeekDaysRecorded

        if days >= 7 {
            return "Every day recorded — a monolith mints when the week closes."
        }

        return "\(days) of 7 days recorded — a monolith mints if the week holds."
    }

    /// Weekday symbols rotated so they start on the calendar's first weekday,
    /// matching the order of `currentWeekDayFlags`.
    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

#Preview {
    VaultView(store: .preview, onClose: {})
}
