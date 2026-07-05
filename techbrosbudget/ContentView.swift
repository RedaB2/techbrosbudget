//
//  ContentView.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 6/14/26.
//

import CloudKit
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
    @State private var expandedPeriod: BudgetPeriod?
    @State private var bottomOverscroll: CGFloat = 0
    @StateObject private var moneyRain = MoneyRainSimulator()
    @State private var vaultProgress: CGFloat = 0
    @State private var isVaultOpen = false
    @State private var logoCenter: CGPoint = .zero
    /// Highest logged-expense milestone already celebrated with money rain,
    /// so each milestone rains exactly once per device.
    @AppStorage("celebratedExpenseMilestone") private var celebratedExpenseMilestone = 0

    /// How far a drag must travel to fully reveal the vault.
    private static let vaultRevealDistance: CGFloat = 320

    @MainActor
    init(store: BudgetStore? = nil) {
        _store = StateObject(wrappedValue: store ?? BudgetStore())
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                BudgetBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MonolithHeader(
                            onSettings: { isShowingSettings = true },
                            onVault: { setVault(open: true) },
                            onLogoTap: { logoCenter in
                                moneyRain.burst(from: logoCenter)
                            },
                            onLogoMoved: { center in
                                logoCenter = center
                            }
                        )

                        MonolithTotals(store: store, expandedPeriod: $expandedPeriod)
                            .padding(.top, 30)

                        RecentSection(store: store)
                            .padding(.top, 44)

                        ChatPullAffordance(overscroll: bottomOverscroll)
                            .padding(.top, 28)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 6)
                    .padding(.bottom, 130)
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    max(0, geo.contentOffset.y + geo.containerSize.height - geo.contentSize.height)
                } action: { _, overscroll in
                    bottomOverscroll = overscroll
                    if overscroll > 80 && !isShowingChat {
                        isShowingChat = true
                    }
                }

                Button {
                    isAddingExpense = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .thin))
                        .foregroundStyle(Monolith.primary)
                }
                .buttonStyle(MonolithRingButtonStyle(diameter: 64))
                .accessibilityLabel("Add expense")
                .padding(.bottom, 24)

                vaultLayer

                MoneyRainOverlay(simulator: moneyRain)
            }
            .simultaneousGesture(vaultOpenGesture)
            .sensoryFeedback(.impact(weight: .light), trigger: expandedPeriod)
            .sensoryFeedback(.impact(weight: .medium), trigger: isVaultOpen)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAddingExpense) {
                AddExpenseView(store: store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(store: store)
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
            .onChange(of: store.expenses.count) { oldCount, newCount in
                if newCount > oldCount {
                    celebrateMilestoneIfReached(totalLogged: newCount)
                }
            }
        }
    }

    // MARK: - Vault

    /// The Vault sits offscreen to the left of the home screen and tracks the
    /// finger during a left-to-right swipe, sliding fully in past a threshold.
    private var vaultLayer: some View {
        GeometryReader { geo in
            VaultView(store: store) {
                setVault(open: false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Monolith.hairline)
                    .frame(width: 1)
                    .ignoresSafeArea()
            }
            .offset(x: (vaultProgress - 1) * geo.size.width)
            .simultaneousGesture(vaultCloseGesture)
        }
        .accessibilityHidden(vaultProgress < 1)
    }

    private var vaultOpenGesture: some Gesture {
        DragGesture(minimumDistance: 25)
            .onChanged { value in
                guard !isVaultOpen else { return }

                let translation = value.translation
                guard translation.width > 0, abs(translation.width) > abs(translation.height) else {
                    return
                }

                vaultProgress = min(1, translation.width / Self.vaultRevealDistance)
            }
            .onEnded { value in
                guard !isVaultOpen else { return }
                guard vaultProgress > 0 else { return }

                let opens = vaultProgress > 0.35
                    || value.predictedEndTranslation.width > Self.vaultRevealDistance
                setVault(open: opens)
            }
    }

    private var vaultCloseGesture: some Gesture {
        DragGesture(minimumDistance: 25)
            .onChanged { value in
                guard isVaultOpen else { return }

                let translation = value.translation
                guard translation.width < 0, abs(translation.width) > abs(translation.height) else {
                    return
                }

                vaultProgress = max(0, 1 + translation.width / Self.vaultRevealDistance)
            }
            .onEnded { value in
                guard isVaultOpen else { return }

                let closes = vaultProgress < 0.65
                    || value.predictedEndTranslation.width < -Self.vaultRevealDistance
                setVault(open: !closes)
            }
    }

    private func setVault(open: Bool) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            vaultProgress = open ? 1 : 0
        }
        isVaultOpen = open
    }

    // MARK: - Milestones

    /// Reaching a logged-expense milestone throws cash from the TECH BROS logo.
    private func celebrateMilestoneIfReached(totalLogged: Int) {
        guard let milestone = VaultLedger.expenseMilestones.last(where: { $0.count <= totalLogged }),
              milestone.count > celebratedExpenseMilestone else {
            return
        }

        celebratedExpenseMilestone = milestone.count

        Task { @MainActor in
            // Let the add-expense sheet settle before it starts raining.
            try? await Task.sleep(for: .seconds(0.5))

            for _ in 0..<3 {
                guard logoCenter != .zero else { break }

                moneyRain.burst(from: logoCenter)
                try? await Task.sleep(for: .seconds(0.25))
            }
        }
    }
}

// MARK: - Header

private struct MonolithHeader: View {
    let onSettings: () -> Void
    let onVault: () -> Void
    let onLogoTap: (CGPoint) -> Void
    let onLogoMoved: (CGPoint) -> Void

    @State private var jiggleCount = 0
    @State private var logoCenter: CGPoint = .zero

    var body: some View {
        ZStack {
            Button {
                jiggleCount += 1
                onLogoTap(logoCenter)
            } label: {
                Image("BrandLogoForeground")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
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
                onLogoMoved(center)
            }
            .accessibilityLabel("Tech Bros logo")
            .accessibilityHint("Makes it rain dollars")

            HStack {
                MonolithIconButton(systemName: "rectangle.portrait", action: onVault)
                    .accessibilityLabel("The Vault")
                    .accessibilityHint("Shows your logging record and minted monoliths")

                Spacer()

                MonolithIconButton(systemName: "gearshape", action: onSettings)
                    .accessibilityLabel("Settings")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LogoJiggle {
    var angle: Double = 0
    var scale: Double = 1
}

// MARK: - The three numbers

private struct MonolithTotals: View {
    @ObservedObject var store: BudgetStore
    @Binding var expandedPeriod: BudgetPeriod?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array([BudgetPeriod.day, .week, .month].enumerated()), id: \.element) { index, period in
                if index > 0 {
                    MonolithDivider()
                        .padding(.vertical, 22)
                }

                MonolithPeriodRow(
                    store: store,
                    period: period,
                    isExpanded: expandedPeriod == period,
                    onToggle: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            expandedPeriod = expandedPeriod == period ? nil : period
                        }
                    }
                )
            }
        }
    }
}

private struct MonolithPeriodRow: View {
    @ObservedObject var store: BudgetStore
    let period: BudgetPeriod
    let isExpanded: Bool
    let onToggle: () -> Void

    private var comparison: SpendingComparison {
        store.comparison(for: period)
    }

    private var trendAccent: Color {
        if comparison.isIncrease { return Monolith.negative }
        if comparison.isDecrease { return Monolith.positive }
        return Monolith.tertiary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        MonolithLabel(rowTitle)
                            .accessibilityLabel(period.title)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Monolith.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }

                    MonolithAmountText(
                        amount: store.total(for: period),
                        size: period == .day ? 60 : 40,
                        countsUpOnAppear: period == .day
                    )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapses details" : "Expands details")

            if isExpanded {
                expandedDetail
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }

    private var rowTitle: String {
        switch period {
        case .day:
            return "Today"
        case .week:
            return "This Week"
        case .month:
            return "This Month"
        }
    }

    private var expandedDetail: some View {
        let periodExpenses = store.expenses(for: period)

        return VStack(alignment: .leading, spacing: 13) {
            MonolithDeltaLine(comparison: comparison)

            HStack(spacing: 14) {
                Sparkline(values: store.trend(for: period), accent: trendAccent)
                    .frame(width: 120, height: 24)

                MonolithLabel(
                    "\(periodExpenses.count) \(periodExpenses.count == 1 ? "transaction" : "transactions")",
                    size: 9,
                    color: Monolith.tertiary
                )
            }

            if period != .day {
                MonolithTextTabs(options: windowOptions, selection: windowSelection)
                    .padding(.top, 3)
            }

            NavigationLink(value: period) {
                HStack(spacing: 7) {
                    MonolithLabel("All transactions", size: 9)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Monolith.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 3)
        }
    }

    private var windowOptions: [(value: SpendingWindowMode, title: String)] {
        SpendingWindowMode.allCases.map { mode in
            (mode, period == .week ? mode.weekTitle : mode.monthTitle)
        }
    }

    private var windowSelection: Binding<SpendingWindowMode> {
        period == .week ? $store.weekWindowMode : $store.monthWindowMode
    }
}

// MARK: - Category row

private struct CategoryRow: View {
    let category: SpendingCategory
    let total: Decimal

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: category.symbol)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Monolith.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)

            Text(category.rawValue)
                .font(.system(size: 14))
                .foregroundStyle(Monolith.primary)
                .lineLimit(1)

            Spacer()

            Text(MoneyFormatter.currency(total))
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(Monolith.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Recent

private struct RecentSection: View {
    @ObservedObject var store: BudgetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                MonolithLabel("Recent")
                    .accessibilityLabel("Recent")

                Spacer()

                if !store.expenses.isEmpty {
                    Text("\(store.expenses.count)")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Monolith.tertiary)
                }
            }
            .padding(.bottom, 6)

            if store.expenses.isEmpty {
                MonolithEmptyRow(
                    icon: "plus.forwardslash.minus",
                    title: "Nothing logged",
                    subtitle: "Use the plus button when you spend money."
                )
            } else {
                ForEach(Array(store.expenses.prefix(8).enumerated()), id: \.element.id) { index, expense in
                    if index > 0 {
                        MonolithDivider()
                    }

                    ExpenseRow(expense: expense) {
                        store.removeExpense(expense)
                    }
                }
            }
        }
    }
}

private struct ExpenseRow: View {
    let expense: Expense
    let onDelete: () -> Void

    private static let revealWidth: CGFloat = 76

    @State private var offset: CGFloat = 0
    @State private var isRevealed = false

    var body: some View {
        rowContent
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Delete expense") {
                performDelete()
            }
            // Opaque so the row slides over the delete action instead of
            // the action showing through the transparent row.
            .background(Monolith.background)
            .offset(x: offset)
            .background(alignment: .trailing) {
                deleteAction
            }
            // Match native swipe actions: sliding content clips at the row
            // bounds instead of escaping past the screen margin.
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                if isRevealed {
                    settle(revealed: false)
                }
            }
            .gesture(swipeGesture)
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(expense.note.isEmpty ? "Expense" : expense.note)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Monolith.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(expense.category.rawValue.uppercased())
                        .kerning(1.2)

                    Text("·")
                        .accessibilityHidden(true)

                    Text(expense.date, format: .dateTime.month(.abbreviated).day().hour().minute())

                    if expense.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 8, weight: .semibold))
                            .accessibilityLabel("Recurring")
                    }

                    if expense.categorizationState == .pending {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Monolith.tertiary)
                            .accessibilityLabel("Categorization pending")
                    }
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Monolith.tertiary)
            }

            Spacer(minLength: 8)

            Text(MoneyFormatter.currency(expense.amount))
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(Monolith.primary)
                .lineLimit(1)
        }
        .padding(.vertical, 12)
    }

    private var deleteAction: some View {
        Button(role: .destructive, action: performDelete) {
            Image(systemName: "trash")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Monolith.negative)
                .frame(width: Self.revealWidth)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete expense")
        .accessibilityHidden(!isRevealed)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                let base: CGFloat = isRevealed ? -Self.revealWidth : 0
                let proposed = base + value.translation.width

                if proposed >= 0 {
                    offset = 0
                } else if proposed < -Self.revealWidth {
                    // Rubber-band past the action width.
                    offset = -Self.revealWidth + (proposed + Self.revealWidth) / 3
                } else {
                    offset = proposed
                }
            }
            .onEnded { _ in
                settle(revealed: offset < -Self.revealWidth * 0.55)
            }
    }

    private func settle(revealed: Bool) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isRevealed = revealed
            offset = revealed ? -Self.revealWidth : 0
        }
    }

    private func performDelete() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isRevealed = false
            offset = 0
            onDelete()
        }
    }
}

// MARK: - Period detail

private struct PeriodDetailView: View {
    @ObservedObject var store: BudgetStore
    let period: BudgetPeriod

    private var periodExpenses: [Expense] {
        store.expenses(for: period)
    }

    private var comparison: SpendingComparison {
        store.comparison(for: period)
    }

    private var trendAccent: Color {
        if comparison.isIncrease { return Monolith.negative }
        if comparison.isDecrease { return Monolith.positive }
        return Monolith.tertiary
    }

    var body: some View {
        ZStack {
            BudgetBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        MonolithLabel(period.title)
                            .accessibilityLabel(period.title)

                        Spacer()

                        MonolithLabel(store.subtitle(for: period), size: 9, color: Monolith.tertiary)
                    }

                    MonolithAmountText(
                        amount: store.total(for: period),
                        size: 56,
                        countsUpOnAppear: true
                    )
                    .padding(.top, 10)

                    MonolithDeltaLine(comparison: comparison)
                        .padding(.top, 12)

                    HStack(spacing: 14) {
                        Sparkline(values: store.trend(for: period), accent: trendAccent)
                            .frame(width: 120, height: 24)

                        MonolithLabel(
                            "\(periodExpenses.count) \(periodExpenses.count == 1 ? "transaction" : "transactions") in this window",
                            size: 9,
                            color: Monolith.tertiary
                        )
                    }
                    .padding(.top, 13)

                    if period != .day {
                        MonolithTextTabs(options: windowOptions, selection: windowSelection)
                            .padding(.top, 22)
                    }

                    MonolithDivider()
                        .padding(.vertical, 26)

                    MonolithLabel("Category summary")
                        .padding(.bottom, 6)

                    if categoryTotals.isEmpty {
                        MonolithEmptyRow(
                            icon: "chart.pie",
                            title: "No category totals",
                            subtitle: "Transactions in this window will appear here."
                        )
                    } else {
                        ForEach(Array(categoryTotals.enumerated()), id: \.element.category) { index, item in
                            if index > 0 {
                                MonolithDivider()
                            }

                            CategoryRow(category: item.category, total: item.total)
                        }
                    }

                    MonolithDivider()
                        .padding(.vertical, 26)

                    HStack {
                        MonolithLabel(period.transactionTitle)

                        Spacer()

                        Text("\(periodExpenses.count)")
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Monolith.tertiary)
                    }
                    .padding(.bottom, 6)

                    if periodExpenses.isEmpty {
                        MonolithEmptyRow(
                            icon: "tray",
                            title: "No transactions",
                            subtitle: "Nothing has been added for this window."
                        )
                    } else {
                        ForEach(Array(periodExpenses.enumerated()), id: \.element.id) { index, expense in
                            if index > 0 {
                                MonolithDivider()
                            }

                            ExpenseRow(expense: expense) {
                                store.removeExpense(expense)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(period.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

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

    private var windowOptions: [(value: SpendingWindowMode, title: String)] {
        SpendingWindowMode.allCases.map { mode in
            (mode, period == .week ? mode.weekTitle : mode.monthTitle)
        }
    }

    private var windowSelection: Binding<SpendingWindowMode> {
        period == .week ? $store.weekWindowMode : $store.monthWindowMode
    }
}

// MARK: - Settings

private struct SettingsView: View {
    @ObservedObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearanceSetting.storageKey) private var appearanceRawValue = AppearanceSetting.system.rawValue
    @State private var intelligenceSummary = AppleIntelligenceSpendingCategorizer.availabilitySummary()
    @State private var iCloudAccountStatus = ICloudAccountStatus.checking

    private var appearanceSelection: Binding<AppearanceSetting> {
        Binding(
            get: { AppearanceSetting(rawValue: appearanceRawValue) ?? .system },
            set: { appearanceRawValue = $0.rawValue }
        )
    }

    private var syncPresentation: SyncStatusPresentation {
        SyncStatusPresentation(
            storageBackend: store.storageBackend,
            iCloudAccountStatus: iCloudAccountStatus
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BudgetBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MonolithLabel("Appearance")
                            .padding(.bottom, 16)

                        MonolithTextTabs(
                            options: AppearanceSetting.allCases.map { ($0, $0.title) },
                            selection: appearanceSelection
                        )

                        Text("System matches your device's light or dark mode setting.")
                            .font(.system(size: 12))
                            .foregroundStyle(Monolith.tertiary)
                            .padding(.top, 14)

                        MonolithDivider()
                            .padding(.vertical, 26)

                        MonolithLabel("Apple Intelligence")
                            .accessibilityLabel("Apple Intelligence")
                            .padding(.bottom, 14)

                        SettingsStatusRow(
                            icon: intelligenceSummary.isAvailable ? "sparkles" : "exclamationmark.triangle",
                            iconTint: intelligenceSummary.isAvailable ? Monolith.secondary : Monolith.negative,
                            title: intelligenceSummary.title,
                            detail: intelligenceSummary.detail,
                            showsProgress: false
                        )

                        Text("Expense categorization uses Apple's Foundation Models on device. No API key is stored, and no expense description is sent to an external AI server.")
                            .font(.system(size: 12))
                            .foregroundStyle(Monolith.tertiary)
                            .padding(.top, 12)

                        MonolithDivider()
                            .padding(.vertical, 26)

                        MonolithLabel("Data Sync")
                            .padding(.bottom, 14)

                        SettingsStatusRow(
                            icon: syncPresentation.iconName,
                            iconTint: Monolith.secondary,
                            title: syncPresentation.title,
                            detail: syncPresentation.detail,
                            showsProgress: syncPresentation.showsProgress
                        )

                        Text("This shows the current storage path and iCloud account availability. iOS manages the exact upload and download timing.")
                            .font(.system(size: 12))
                            .foregroundStyle(Monolith.tertiary)
                            .padding(.top, 12)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(Monolith.primary)
                }
            }
            .onAppear {
                intelligenceSummary = AppleIntelligenceSpendingCategorizer.availabilitySummary()
            }
            .task {
                await refreshICloudAccountStatus()
            }
        }
        // A sheet is its own presentation, so the scheme set at the app root
        // doesn't reach it while it stays open — apply it here too so theme
        // changes take effect on this sheet immediately.
        .preferredColorScheme(appearanceSelection.wrappedValue.preferredColorScheme)
    }

    @MainActor
    private func refreshICloudAccountStatus() async {
        guard case .cloudKitPrivateDatabase(let containerIdentifier) = store.storageBackend else {
            iCloudAccountStatus = .notApplicable
            return
        }

        iCloudAccountStatus = .checking
        iCloudAccountStatus = await ICloudAccountStatus.current(containerIdentifier: containerIdentifier)
    }
}

private struct SettingsStatusRow: View {
    let icon: String
    let iconTint: Color
    let title: String
    let detail: String
    let showsProgress: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(Monolith.secondary)
                    .frame(width: 24)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(iconTint)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Monolith.primary)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Monolith.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private enum ICloudAccountStatus: Equatable {
    case notApplicable
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine

    static func current(containerIdentifier: String) async -> ICloudAccountStatus {
        await withCheckedContinuation { continuation in
            CKContainer(identifier: containerIdentifier).accountStatus { status, error in
                guard error == nil else {
                    continuation.resume(returning: .couldNotDetermine)
                    return
                }

                continuation.resume(returning: ICloudAccountStatus(status))
            }
        }
    }

    init(_ status: CKAccountStatus) {
        switch status {
        case .available:
            self = .available
        case .noAccount:
            self = .noAccount
        case .restricted:
            self = .restricted
        case .temporarilyUnavailable:
            self = .temporarilyUnavailable
        case .couldNotDetermine:
            self = .couldNotDetermine
        @unknown default:
            self = .couldNotDetermine
        }
    }
}

private struct SyncStatusPresentation {
    let title: String
    let detail: String
    let iconName: String
    let showsProgress: Bool

    private init(
        title: String,
        detail: String,
        iconName: String,
        showsProgress: Bool
    ) {
        self.title = title
        self.detail = detail
        self.iconName = iconName
        self.showsProgress = showsProgress
    }

    init(storageBackend: BudgetStorageBackend, iCloudAccountStatus: ICloudAccountStatus) {
        switch storageBackend {
        case .cloudKitPrivateDatabase:
            self = Self.cloudKitStatus(iCloudAccountStatus: iCloudAccountStatus)
        case .localDeviceOnly:
            self = Self(
                title: "Stored on this device",
                detail: "iCloud sync is not active on this launch. Expenses are saved locally only.",
                iconName: "externaldrive",
                showsProgress: false
            )
        case .preview:
            self = Self(
                title: "Preview data",
                detail: "This run uses local preview data and does not sync to iCloud.",
                iconName: "eye",
                showsProgress: false
            )
        }
    }

    private static func cloudKitStatus(iCloudAccountStatus: ICloudAccountStatus) -> SyncStatusPresentation {
        switch iCloudAccountStatus {
        case .notApplicable, .checking:
            return SyncStatusPresentation(
                title: "Checking iCloud sync",
                detail: "Looking up this device's iCloud account status.",
                iconName: "icloud",
                showsProgress: true
            )
        case .available:
            return SyncStatusPresentation(
                title: "Syncing to iCloud",
                detail: "Expenses, recurring schedules, and window preferences use your private iCloud database.",
                iconName: "icloud",
                showsProgress: false
            )
        case .noAccount:
            return SyncStatusPresentation(
                title: "Local until signed in to iCloud",
                detail: "Sign in to iCloud on this device to sync expenses.",
                iconName: "icloud.slash",
                showsProgress: false
            )
        case .restricted:
            return SyncStatusPresentation(
                title: "iCloud sync restricted",
                detail: "This device or account restricts iCloud access, so data may remain local here.",
                iconName: "lock",
                showsProgress: false
            )
        case .temporarilyUnavailable:
            return SyncStatusPresentation(
                title: "iCloud temporarily unavailable",
                detail: "iOS cannot reach iCloud account services right now. Sync should resume when available.",
                iconName: "exclamationmark.triangle",
                showsProgress: false
            )
        case .couldNotDetermine:
            return SyncStatusPresentation(
                title: "Sync status unavailable",
                detail: "The app is configured for CloudKit, but iOS could not confirm the current iCloud account status.",
                iconName: "questionmark.circle",
                showsProgress: false
            )
        }
    }
}

// MARK: - Info disclosure

/// A muted info glyph that toggles a bound flag. Lets an explanatory line stay
/// hidden until the user asks for it, keeping the form uncluttered.
private struct MonolithInfoButton: View {
    @Binding var isOn: Bool
    let subject: String

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isOn ? Monolith.secondary : Monolith.tertiary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Hide info about \(subject)" : "Show info about \(subject)")
    }
}

/// A section label paired with an info button, so the header can reveal its own
/// help text on demand.
private struct MonolithInfoLabel: View {
    let title: String
    @Binding var isShowingInfo: Bool

    var body: some View {
        HStack(spacing: 8) {
            MonolithLabel(title)
            MonolithInfoButton(isOn: $isShowingInfo, subject: title)
            Spacer(minLength: 0)
        }
    }
}

/// Small helper for the muted explanatory lines revealed by an info button.
private struct MonolithInfoText: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Monolith.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Add expense

private struct AddExpenseView: View {
    @ObservedObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var amountText = ""
    @State private var note = ""
    @State private var isRecurring = false
    @State private var recurrenceFrequency = RecurrenceFrequency.monthly
    @State private var isShowingNoteInfo = false
    @State private var isShowingRecurringInfo = false

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

    private var currencySymbol: String {
        Locale.current.currencySymbol ?? "$"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BudgetBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MonolithLabel("Amount")
                            .padding(.bottom, 4)

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(currencySymbol)
                                .font(.system(size: 40, weight: .ultraLight))
                                .foregroundStyle(Monolith.tertiary)

                            TextField("0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 56, weight: .ultraLight).monospacedDigit())
                                .foregroundStyle(Monolith.primary)
                                .focused($focusedField, equals: .amount)
                                .accessibilityLabel("Amount")
                        }

                        MonolithDivider()
                            .padding(.top, 6)

                        MonolithInfoLabel(title: "Note", isShowingInfo: $isShowingNoteInfo)
                            .padding(.top, 30)
                            .padding(.bottom, 10)

                        TextField("Coffee, team lunch, taxi to the office", text: $note, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .font(.system(size: 15))
                            .foregroundStyle(Monolith.primary)
                            .focused($focusedField, equals: .note)
                            .accessibilityLabel("Description")

                        MonolithDivider()
                            .padding(.top, 6)

                        if isShowingNoteInfo {
                            MonolithInfoText("Totals update immediately. The category is assigned automatically after this screen closes.")
                                .padding(.top, 12)
                        }

                        HStack(spacing: 8) {
                            MonolithLabel("Recurring expense")

                            MonolithInfoButton(isOn: $isShowingRecurringInfo, subject: "Recurring expense")

                            Spacer()

                            Toggle("", isOn: $isRecurring.animation())
                                .labelsHidden()
                                .tint(Monolith.secondary)
                                .accessibilityLabel("Recurring expense")
                        }
                        .padding(.top, 34)

                        if isShowingRecurringInfo {
                            if isRecurring {
                                MonolithInfoText("Great for subscriptions. Future charges are logged automatically every \(recurrenceFrequency.intervalNoun), starting \(recurrenceFrequency.nextDate(after: Date()), format: .dateTime.month(.abbreviated).day()).")
                                    .padding(.top, 14)
                            } else {
                                MonolithInfoText("Turn this on for subscriptions and other charges that repeat on a schedule.")
                                    .padding(.top, 14)
                            }
                        }

                        if isRecurring {
                            MonolithTextTabs(
                                options: RecurrenceFrequency.allCases.map { ($0, $0.title) },
                                selection: $recurrenceFrequency
                            )
                            .padding(.top, 16)
                        }

                        Button {
                            save()
                        } label: {
                            Text("Add expense")
                        }
                        .buttonStyle(MonolithBlockButtonStyle())
                        .accessibilityIdentifier("SaveExpenseButton")
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.35)
                        .padding(.top, 36)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Add spending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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

// MARK: - Chat pull affordance

private struct ChatPullAffordance: View {
    let overscroll: CGFloat

    private var progress: CGFloat {
        min(max(0, overscroll) / 80, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Monolith.secondary.opacity(0.5 + progress * 0.5))
                .scaleEffect(0.8 + progress * 0.3)
                .offset(y: -progress * 6)

            MonolithLabel("Pull to chat", size: 9, color: Monolith.tertiary)
                .accessibilityLabel("Pull to chat")
                .opacity(0.6 + progress * 0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: overscroll)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pull up to open Budget Chat")
    }
}

#Preview {
    ContentView()
}
