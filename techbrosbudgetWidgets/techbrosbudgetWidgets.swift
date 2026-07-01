//
//  techbrosbudgetWidgets.swift
//  techbrosbudgetWidgets
//
//  Created by OpenAI on 6/28/26.
//

import AppIntents
import SwiftUI
import WidgetKit

struct BudgetWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: BudgetWidgetSnapshot
    let selectedPeriod: BudgetPeriod

    var selectedTotal: BudgetWidgetPeriodTotal {
        snapshot.total(for: selectedPeriod)
    }
}

struct SelectedBudgetTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BudgetWidgetEntry {
        BudgetWidgetEntry(
            date: Date(),
            snapshot: BudgetWidgetDataStore.previewSnapshot(),
            selectedPeriod: .month
        )
    }

    func snapshot(for configuration: BudgetPeriodSelectionIntent, in context: Context) async -> BudgetWidgetEntry {
        BudgetWidgetEntry(
            date: Date(),
            snapshot: context.isPreview ? BudgetWidgetDataStore.previewSnapshot() : BudgetWidgetDataStore.loadSnapshot(),
            selectedPeriod: configuration.period?.budgetWidgetPeriod ?? .month
        )
    }

    func timeline(for configuration: BudgetPeriodSelectionIntent, in context: Context) async -> Timeline<BudgetWidgetEntry> {
        let now = Date()
        let entry = BudgetWidgetEntry(
            date: now,
            snapshot: BudgetWidgetDataStore.loadSnapshot(now: now),
            selectedPeriod: configuration.period?.budgetWidgetPeriod ?? .month
        )
        return Timeline(entries: [entry], policy: .after(nextRefreshDate(after: now)))
    }
}

struct OverviewBudgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetWidgetEntry {
        BudgetWidgetEntry(
            date: Date(),
            snapshot: BudgetWidgetDataStore.previewSnapshot(),
            selectedPeriod: .month
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetWidgetEntry) -> Void) {
        completion(
            BudgetWidgetEntry(
                date: Date(),
                snapshot: context.isPreview ? BudgetWidgetDataStore.previewSnapshot() : BudgetWidgetDataStore.loadSnapshot(),
                selectedPeriod: .month
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetWidgetEntry>) -> Void) {
        let now = Date()
        let entry = BudgetWidgetEntry(
            date: now,
            snapshot: BudgetWidgetDataStore.loadSnapshot(now: now),
            selectedPeriod: .month
        )
        completion(Timeline(entries: [entry], policy: .after(nextRefreshDate(after: now))))
    }
}

struct SelectedBudgetWidgetView: View {
    let entry: BudgetWidgetEntry

    var body: some View {
        let total = entry.selectedTotal

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                BudgetWidgetIcon(period: total.period, size: 34)

                Spacer(minLength: 8)

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(total.period.widgetLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(MoneyFormatter.currency(total.amount))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.54)
                    .lineLimit(1)

                Text(total.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .containerBackground(for: .widget) {
            BudgetWidgetBackground()
        }
    }
}

struct BudgetOverviewWidgetView: View {
    let entry: BudgetWidgetEntry
    @Environment(\.widgetFamily) private var widgetFamily

    private var totals: [BudgetWidgetPeriodTotal] {
        [BudgetPeriod.month, .week, .day].map { entry.snapshot.total(for: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: widgetFamily == .systemLarge ? 14 : 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Spending")
                    .font(.headline.weight(.bold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(entry.snapshot.generatedAt, format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(spacing: widgetFamily == .systemLarge ? 12 : 8) {
                ForEach(totals) { total in
                    BudgetPeriodTotalRow(total: total, showsSubtitle: widgetFamily == .systemLarge)
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) {
            BudgetWidgetBackground()
        }
    }
}

struct BudgetPeriodTotalRow: View {
    let total: BudgetWidgetPeriodTotal
    let showsSubtitle: Bool

    var body: some View {
        HStack(spacing: 10) {
            BudgetWidgetIcon(period: total.period, size: showsSubtitle ? 36 : 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(total.period.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if showsSubtitle {
                    Text(total.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(MoneyFormatter.currency(total.amount))
                .font(.subheadline.monospacedDigit().weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .accessibilityElement(children: .combine)
    }
}

struct BudgetWidgetIcon: View {
    let period: BudgetPeriod
    let size: CGFloat

    var body: some View {
        Image(systemName: period.symbolName)
            .font(.system(size: size * 0.44, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(period.tint.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

struct BudgetWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.mint.opacity(0.24),
                Color.orange.opacity(0.16),
                Color.indigo.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct SelectedBudgetWidget: Widget {
    let kind = "SelectedBudgetWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: BudgetPeriodSelectionIntent.self,
            provider: SelectedBudgetTimelineProvider()
        ) { entry in
            SelectedBudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("Budget Amount")
        .description("Pick monthly, weekly, or daily spending for the smallest widget.")
        .supportedFamilies([.systemSmall])
    }
}

struct BudgetOverviewWidget: Widget {
    let kind = "BudgetOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: OverviewBudgetTimelineProvider()
        ) { entry in
            BudgetOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Budget Overview")
        .description("See monthly, weekly, and daily spending together.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct TechBrosBudgetWidgets: WidgetBundle {
    var body: some Widget {
        SelectedBudgetWidget()
        BudgetOverviewWidget()
    }
}

private extension BudgetPeriod {
    var widgetLabel: String {
        switch self {
        case .day:
            return "Daily"
        case .week:
            return "Weekly"
        case .month:
            return "Monthly"
        }
    }

    var symbolName: String {
        switch self {
        case .day:
            return "sun.max"
        case .week:
            return "calendar.badge.clock"
        case .month:
            return "calendar"
        }
    }

    var tint: Color {
        switch self {
        case .day:
            return .orange
        case .week:
            return .indigo
        case .month:
            return .mint
        }
    }
}

private func nextRefreshDate(after date: Date) -> Date {
    Calendar.current.date(byAdding: .minute, value: 30, to: date) ?? date.addingTimeInterval(1_800)
}
