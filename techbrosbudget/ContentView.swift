//
//  ContentView.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 6/14/26.
//

import SwiftUI

private func opensBudgetChatForUITests() -> Bool {
    #if DEBUG
    ProcessInfo.processInfo.arguments.contains("UITEST_MARKDOWN_CHAT")
    #else
    false
    #endif
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: BudgetStore
    @State private var isAddingExpense = false
    @State private var isShowingSettings = false
    @State private var isShowingChat = opensBudgetChatForUITests()
    @State private var bottomOverscroll: CGFloat = 0
    @StateObject private var moneyRain = MoneyRainSimulator()

    @MainActor
    init(store: BudgetStore? = nil) {
        _store = StateObject(wrappedValue: store ?? BudgetStore())
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                BudgetBackground()

                ScrollView {
                    GlassEffectContainer(spacing: 18) {
                        VStack(alignment: .leading, spacing: 18) {
                            HeaderView(
                                onSettings: { isShowingSettings = true },
                                onLogoTap: { logoCenter in
                                    moneyRain.burst(from: logoCenter)
                                }
                            )

                            TotalsStack(store: store)

                            WindowControls(store: store)

                            CategoryBreakdown(store: store)

                            RecentExpensesView(store: store)

                            ChatPullAffordance(overscroll: bottomOverscroll)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 110)
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    max(0, geo.contentOffset.y + geo.containerSize.height - geo.contentSize.height)
                } action: { _, overscroll in
                    bottomOverscroll = overscroll
                    if overscroll > 80 && !isShowingChat {
                        isShowingChat = true
                    }
                }

                Button(action: { isAddingExpense = true }) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel("Add expense")
                .padding(.trailing, 20)
                .padding(.bottom, 20)

                MoneyRainOverlay(simulator: moneyRain)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAddingExpense) {
                AddExpenseView(store: store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingChat) {
                BudgetChatView(store: store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .navigationDestination(for: BudgetPeriod.self) { period in
                PeriodDetailView(store: store, period: period)
            }
            .onAppear {
                store.reloadPersistedData()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    store.reloadPersistedData()
                }
            }
        }
    }
}

private struct HeaderView: View {
    let onSettings: () -> Void
    let onLogoTap: (CGPoint) -> Void

    @State private var jiggleCount = 0
    @State private var logoCenter: CGPoint = .zero

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    jiggleCount += 1
                    onLogoTap(logoCenter)
                } label: {
                    Image("BrandLogoForeground")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 76, height: 76, alignment: .leading)
                }
                .buttonStyle(.plain)
                .keyframeAnimator(initialValue: LogoJiggle(), trigger: jiggleCount) { view, jiggle in
                    view
                        .rotationEffect(.degrees(jiggle.angle))
                        .scaleEffect(jiggle.scale)
                } keyframes: { _ in
                    KeyframeTrack(\.angle) {
                        CubicKeyframe(-13, duration: 0.09)
                        CubicKeyframe(11, duration: 0.11)
                        CubicKeyframe(-7, duration: 0.11)
                        CubicKeyframe(4, duration: 0.11)
                        CubicKeyframe(0, duration: 0.13)
                    }

                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.12, duration: 0.12)
                        CubicKeyframe(0.97, duration: 0.18)
                        CubicKeyframe(1.0, duration: 0.25)
                    }
                }
                .sensoryFeedback(.impact(weight: .light), trigger: jiggleCount)
                .onGeometryChange(for: CGPoint.self) { proxy in
                    let frame = proxy.frame(in: .global)
                    return CGPoint(x: frame.midX, y: frame.midY)
                } action: { center in
                    logoCenter = center
                }
                .accessibilityLabel("Tech Bros logo")
                .accessibilityHint("Makes it rain dollars")
            }

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Settings")
        }
    }
}

private struct LogoJiggle {
    var angle: Double = 0
    var scale: Double = 1
}

private struct TotalsStack: View {
    @ObservedObject var store: BudgetStore

    var body: some View {
        VStack(spacing: 14) {
            ForEach([BudgetPeriod.month, .week, .day]) { period in
                NavigationLink(value: period) {
                    TotalCard(
                        title: period.title,
                        subtitle: store.subtitle(for: period),
                        amount: store.total(for: period),
                        comparison: store.comparison(for: period),
                        icon: icon(for: period),
                        tint: tint(for: period)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func icon(for period: BudgetPeriod) -> String {
        switch period {
        case .day:
            return "sun.max"
        case .week:
            return "calendar.badge.clock"
        case .month:
            return "calendar"
        }
    }

    private func tint(for period: BudgetPeriod) -> Color {
        switch period {
        case .day:
            return .orange
        case .week:
            return .indigo
        case .month:
            return .mint
        }
    }
}

private struct TotalCard: View {
    let title: String
    let subtitle: String
    let amount: Decimal
    let comparison: SpendingComparison
    let icon: String
    let tint: Color

    var body: some View {
        LiquidGlassCard(cornerRadius: 30) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(tint.gradient, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(MoneyFormatter.currency(amount))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.68)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    ComparisonBadge(comparison: comparison)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ComparisonBadge: View {
    let comparison: SpendingComparison

    private var tint: Color {
        if comparison.isIncrease {
            return .red
        }

        if comparison.isDecrease {
            return .green
        }

        return .secondary
    }

    private var symbol: String {
        if comparison.isIncrease {
            return "arrow.up.right"
        }

        if comparison.isDecrease {
            return "arrow.down.right"
        }

        return "minus"
    }

    var body: some View {
        HStack(spacing: 6) {
            Label(MoneyFormatter.percentage(comparison.percentChange), systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.bold))

            Text("vs \(MoneyFormatter.currency(comparison.previousTotal)) \(comparison.previousLabel)")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

private struct WindowControls: View {
    @ObservedObject var store: BudgetStore

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Windows")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Month")
                        .font(.subheadline.weight(.semibold))

                    Picker("Month window", selection: $store.monthWindowMode) {
                        ForEach(SpendingWindowMode.allCases) { mode in
                            Text(mode.monthTitle).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Week")
                        .font(.subheadline.weight(.semibold))

                    Picker("Week window", selection: $store.weekWindowMode) {
                        ForEach(SpendingWindowMode.allCases) { mode in
                            Text(mode.weekTitle).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}

private struct PeriodDetailView: View {
    @ObservedObject var store: BudgetStore
    let period: BudgetPeriod

    private var periodExpenses: [Expense] {
        store.expenses(for: period)
    }

    var body: some View {
        ZStack {
            BudgetBackground()

            ScrollView {
                GlassEffectContainer(spacing: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        PeriodSummaryCard(
                            period: period,
                            subtitle: store.subtitle(for: period),
                            total: store.total(for: period),
                            comparison: store.comparison(for: period),
                            transactionCount: periodExpenses.count
                        )

                        PeriodWindowControl(store: store, period: period)

                        PeriodCategoryBreakdown(store: store, period: period)

                        PeriodTransactionsView(
                            title: period.transactionTitle,
                            expenses: periodExpenses,
                            onDelete: store.removeExpense
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(period.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PeriodSummaryCard: View {
    let period: BudgetPeriod
    let subtitle: String
    let total: Decimal
    let comparison: SpendingComparison
    let transactionCount: Int

    var body: some View {
        LiquidGlassCard(cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(tint.gradient, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(period.title)
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(MoneyFormatter.currency(total))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                ComparisonBadge(comparison: comparison)

                Text("\(transactionCount) \(transactionCount == 1 ? "transaction" : "transactions") in this window")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var icon: String {
        switch period {
        case .day:
            return "sun.max"
        case .week:
            return "calendar.badge.clock"
        case .month:
            return "calendar"
        }
    }

    private var tint: Color {
        switch period {
        case .day:
            return .orange
        case .week:
            return .indigo
        case .month:
            return .mint
        }
    }
}

private struct PeriodWindowControl: View {
    @ObservedObject var store: BudgetStore
    let period: BudgetPeriod

    var body: some View {
        switch period {
        case .day:
            EmptyView()
        case .week:
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Week window")
                        .font(.headline)

                    Picker("Week window", selection: $store.weekWindowMode) {
                        ForEach(SpendingWindowMode.allCases) { mode in
                            Text(mode.weekTitle).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        case .month:
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Month window")
                        .font(.headline)

                    Picker("Month window", selection: $store.monthWindowMode) {
                        ForEach(SpendingWindowMode.allCases) { mode in
                            Text(mode.monthTitle).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}

private struct PeriodCategoryBreakdown: View {
    @ObservedObject var store: BudgetStore
    let period: BudgetPeriod

    private var categoryTotals: [(category: SpendingCategory, total: Decimal)] {
        store.categoryTotals(for: period)
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.rawValue < rhs.key.rawValue
                }

                return lhs.value > rhs.value
            }
            .map { entry in
                (category: entry.key, total: entry.value)
            }
    }

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Category summary")
                    .font(.headline)

                if categoryTotals.isEmpty {
                    EmptyStateRow(
                        icon: "chart.pie",
                        title: "No category totals",
                        subtitle: "Transactions in this window will appear here."
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(categoryTotals, id: \.category) { item in
                            CategoryRow(category: item.category, total: item.total)
                        }
                    }
                }
            }
        }
    }
}

private struct PeriodTransactionsView: View {
    let title: String
    let expenses: [Expense]
    let onDelete: (Expense) -> Void

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Spacer()

                    Text("\(expenses.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if expenses.isEmpty {
                    EmptyStateRow(
                        icon: "tray",
                        title: "No transactions",
                        subtitle: "Nothing has been added for this window."
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(expenses) { expense in
                            ExpenseRow(expense: expense) {
                                onDelete(expense)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct CategoryBreakdown: View {
    @ObservedObject var store: BudgetStore

    private var categoryTotals: [(category: SpendingCategory, total: Decimal)] {
        store.categoryTotals(for: .month)
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.rawValue < rhs.key.rawValue
                }

                return lhs.value > rhs.value
            }
            .map { entry in
                (category: entry.key, total: entry.value)
            }
    }

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Categories")
                        .font(.headline)

                    Spacer()

                    if store.pendingCategorizationCount > 0 {
                        Label("\(store.pendingCategorizationCount)", systemImage: "clock")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                    }
                }

                if categoryTotals.isEmpty {
                    EmptyStateRow(
                        icon: "sparkles",
                        title: "No categories yet",
                        subtitle: "Add an expense and it will be categorized in the background."
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(categoryTotals, id: \.category) { item in
                            CategoryRow(category: item.category, total: item.total)
                        }
                    }
                }
            }
        }
    }
}

private struct CategoryRow: View {
    let category: SpendingCategory
    let total: Decimal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(category.readableTint)
                .frame(width: 30, height: 30)
                .background(category.readableTint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            Text(category.rawValue)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(MoneyFormatter.currency(total))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct RecentExpensesView: View {
    @ObservedObject var store: BudgetStore

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Recent")
                        .font(.headline)

                    Spacer()

                    if !store.expenses.isEmpty {
                        Text("\(store.expenses.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if store.expenses.isEmpty {
                    EmptyStateRow(
                        icon: "plus.forwardslash.minus",
                        title: "Nothing logged",
                        subtitle: "Use the plus button when you spend money."
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.expenses.prefix(8)) { expense in
                            ExpenseRow(expense: expense) {
                                store.removeExpense(expense)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ExpenseRow: View {
    let expense: Expense
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(expense.category.readableTint)
                .frame(width: 34, height: 34)
                .background(expense.category.readableTint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.note.isEmpty ? "Expense" : expense.note)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(expense.category.rawValue)

                    Text("/")
                        .accessibilityHidden(true)

                    Text(expense.date, format: .dateTime.month(.abbreviated).day().hour().minute())

                    if expense.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.cyan)
                            .accessibilityLabel("Recurring")
                    }

                    if expense.categorizationState == .pending {
                        ProgressView()
                            .controlSize(.mini)
                            .accessibilityLabel("Categorization pending")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Text(MoneyFormatter.currency(expense.amount))
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .lineLimit(1)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete expense")
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearanceSetting.storageKey) private var appearanceRawValue = AppearanceSetting.system.rawValue
    @State private var intelligenceSummary = AppleIntelligenceSpendingCategorizer.availabilitySummary()

    private var appearanceSetting: AppearanceSetting {
        AppearanceSetting(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $appearanceRawValue) {
                        ForEach(AppearanceSetting.allCases) { setting in
                            Text(setting.title)
                                .tag(setting.rawValue)
                        }
                    } label: {
                        Label("Theme", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System matches your device's light or dark mode setting.")
                }

                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(intelligenceSummary.title)
                                .font(.body.weight(.semibold))

                            Text(intelligenceSummary.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: intelligenceSummary.isAvailable ? "sparkles" : "exclamationmark.triangle")
                            .foregroundStyle(intelligenceSummary.isAvailable ? .blue : .orange)
                    }
                } header: {
                    Text("Apple Intelligence")
                } footer: {
                    Text("Expense categorization uses Apple's Foundation Models on device. No API key is stored, and no expense description is sent to an external AI server.")
                }

                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Private iCloud sync")
                                .font(.body.weight(.semibold))

                            Text("Expenses and window preferences sync through your private CloudKit database when iCloud is available.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "icloud")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BudgetBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                intelligenceSummary = AppleIntelligenceSpendingCategorizer.availabilitySummary()
            }
        }
    }
}

private struct AddExpenseView: View {
    @ObservedObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var amountText = ""
    @State private var note = ""
    @State private var isRecurring = false
    @State private var recurrenceFrequency = RecurrenceFrequency.monthly

    private enum Field {
        case amount
        case note
    }

    private var parsedAmount: Decimal? {
        MoneyParser.decimal(from: amountText)
    }

    private var canSave: Bool {
        guard let parsedAmount else {
            return false
        }

        return parsedAmount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .focused($focusedField, equals: .amount)
                        .accessibilityLabel("Amount")

                    TextField("Coffee, team lunch, taxi to the office", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .focused($focusedField, equals: .note)
                        .accessibilityLabel("Description")
                } header: {
                    Text("Expense")
                } footer: {
                    Text("Totals update immediately. The category is assigned automatically after this screen closes.")
                }

                Section {
                    Toggle(isOn: $isRecurring.animation()) {
                        Label("Recurring expense", systemImage: "repeat")
                    }

                    if isRecurring {
                        Picker("Repeats", selection: $recurrenceFrequency) {
                            ForEach(RecurrenceFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("Repeat")
                } footer: {
                    if isRecurring {
                        Text("Great for subscriptions. Future charges are logged automatically every \(recurrenceFrequency.intervalNoun), starting \(recurrenceFrequency.nextDate(after: Date()), format: .dateTime.month(.abbreviated).day()).")
                    } else {
                        Text("Turn this on for subscriptions and other charges that repeat on a schedule.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BudgetBackground())
            .navigationTitle("Add spending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                focusedField = .amount
            }
        }
    }

    private func save() {
        guard let parsedAmount, parsedAmount > 0 else {
            return
        }

        store.addExpense(
            amount: parsedAmount,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            recurrence: isRecurring ? recurrenceFrequency : nil
        )
        dismiss()
    }
}

private struct EmptyStateRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
                .background(.secondary.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ChatPullAffordance: View {
    let overscroll: CGFloat

    private var progress: CGFloat {
        min(max(0, overscroll) / 80, 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.teal.opacity(0.4 + progress * 0.6))
                .scaleEffect(0.72 + progress * 0.38)
                .offset(y: -progress * 6)

            Text("Pull to chat")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.45 + progress * 0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: overscroll)
        .accessibilityLabel("Pull up to open Budget Chat")
    }
}

private struct LiquidGlassCard<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    @ViewBuilder var content: Content

    init(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let card = content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(Color(.secondarySystemGroupedBackground))
                    } else {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(Color(.systemBackground).opacity(backgroundOverlayOpacity))
                    }

                    shape.strokeBorder(strokeColor, lineWidth: strokeWidth)
                }
            }

        Group {
            if reduceTransparency {
                card
            } else {
                card.glassEffect(.regular, in: shape)
            }
        }
    }

    private var backgroundOverlayOpacity: Double {
        if colorSchemeContrast == .increased {
            return colorScheme == .dark ? 0.24 : 0.18
        }

        return colorScheme == .dark ? 0.12 : 0.06
    }

    private var strokeColor: Color {
        if colorSchemeContrast == .increased {
            return Color(.label).opacity(colorScheme == .dark ? 0.36 : 0.2)
        }

        return colorScheme == .dark ? .white.opacity(0.18) : .white.opacity(0.4)
    }

    private var strokeWidth: CGFloat {
        colorSchemeContrast == .increased ? 1.25 : 1
    }
}

struct BudgetBackground: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemBackground)

            if !reduceTransparency {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(colorSchemeContrast == .increased ? 0.72 : 1)
            }
        }
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(.systemBackground),
                Color.teal.opacity(0.16),
                Color.blue.opacity(0.11),
                Color.purple.opacity(0.14),
                Color(.systemBackground)
            ]
        }

        return [
            Color(.systemBackground),
            Color.cyan.opacity(0.14),
            Color.mint.opacity(0.16),
            Color.indigo.opacity(0.1),
            Color(.secondarySystemBackground).opacity(0.72)
        ]
    }
}

private extension SpendingCategory {
    var readableTint: Color {
        switch self {
        case .utilities:
            return .orange
        case .giftsAndDonations:
            return .teal
        case .feesAndTaxes, .awkward:
            return .secondary
        default:
            return color
        }
    }
}
