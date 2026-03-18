#if os(macOS)
import Charts
import SwiftUI

// MARK: - Reports Page

struct ReportsPage: View {
    @Environment(\.theme) private var theme
    @StateObject private var viewModel = ReportsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppMetrics.cardGap) {
                // Week navigator
                WeekNavigator(
                    weekLabel: viewModel.weekLabel,
                    isCurrentWeek: viewModel.isCurrentWeek,
                    isLoading: viewModel.isLoading,
                    onPrevious: { viewModel.goToPreviousWeek() },
                    onNext: { viewModel.goToNextWeek() },
                    onCurrent: { viewModel.goToCurrentWeek() }
                )

                // Summary cards row
                WeeklySummaryRow(viewModel: viewModel)

                // Stacked bar chart
                WeeklyBarChart(data: viewModel.weeklyData)

                // Contribution heatmap
                ContributionHeatmap(data: viewModel.heatmapData)
            }
            .padding(AppMetrics.contentPadding)
        }
        .onAppear { viewModel.fetchAll() }
    }
}

// MARK: - Week Navigator

struct WeekNavigator: View {
    let weekLabel: String
    var isCurrentWeek: Bool
    var isLoading: Bool
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onCurrent: (() -> Void)?
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Text(weekLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.foreground)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if !isCurrentWeek {
                    Button { onCurrent?() } label: {
                        Text("This Week")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(theme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 0) {
                    Button { onPrevious?() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.mutedForeground)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Button { onNext?() } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.mutedForeground)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Weekly Summary Row

struct WeeklySummaryRow: View {
    @ObservedObject var viewModel: ReportsViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: AppMetrics.cardGap) {
            summaryCard(title: "TOTAL HOURS", value: viewModel.formatHours(viewModel.weeklyTotal))
            summaryCard(title: "DAILY AVG", value: viewModel.formatHours(viewModel.dailyAverage))
            summaryCard(title: "TOP CATEGORY", value: viewModel.topCategory)
            summaryCard(title: "BEST DAY", value: viewModel.mostProductiveDay)
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(theme.mutedForeground)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard()
    }
}

// MARK: - Weekly Stacked Bar Chart

struct WeeklyBarChart: View {
    let data: [WeeklyDayEntry]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Weekly Activity")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            if data.isEmpty || data.allSatisfy({ $0.totalSeconds == 0 }) {
                Text("No activity recorded")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach(data) { day in
                        ForEach(day.categories) { cat in
                            BarMark(
                                x: .value("Day", day.dayLabel),
                                y: .value("Hours", Double(cat.seconds) / 3600.0)
                            )
                            .foregroundStyle(CategoryColors.color(for: cat.category))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(theme.border)
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text("\(Int(hours))h")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(theme.mutedForeground)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.foreground)
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot.background(Color.clear)
                }
                .frame(height: 220)
                .padding(.horizontal, 16)

                // Legend
                HStack(spacing: 12) {
                    ForEach(uniqueCategories(), id: \.self) { cat in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(CategoryColors.color(for: cat))
                                .frame(width: 8, height: 8)
                            Text(cat)
                                .font(.system(size: 9))
                                .foregroundStyle(theme.mutedForeground)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            Spacer(minLength: 14)
        }
        .dashboardCard()
    }

    private func uniqueCategories() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for day in data {
            for cat in day.categories {
                if !seen.contains(cat.category) {
                    seen.insert(cat.category)
                    result.append(cat.category)
                }
            }
        }
        return result
    }
}

// MARK: - Contribution Heatmap

struct ContributionHeatmap: View {
    let data: [HeatmapDay]
    @Environment(\.theme) private var theme

    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3
    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Activity Heatmap")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            if data.isEmpty {
                Text("No data available")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // Day of week header
                    HStack(spacing: cellSpacing) {
                        // Spacer for week labels
                        Text("")
                            .frame(width: 50)

                        ForEach(dayLabels, id: \.self) { label in
                            Text(label)
                                .font(.system(size: 8))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: cellSize, height: 12)
                        }
                    }
                    .padding(.bottom, 4)

                    // Weeks grid
                    let weeks = groupByWeek()
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        HStack(spacing: cellSpacing) {
                            // Week start date label
                            Text(weekStartLabel(week))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 50, alignment: .trailing)

                            ForEach(0..<7, id: \.self) { dayIndex in
                                let day = dayForIndex(week: week, dayIndex: dayIndex)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(heatmapColor(for: day))
                                    .frame(width: cellSize, height: cellSize)
                                    .help(heatmapTooltip(for: day))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Legend
                HStack(spacing: 4) {
                    Spacer()
                    Text("Less")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.mutedForeground)
                    ForEach([0.0, 0.15, 0.35, 0.6, 0.9], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(opacity == 0 ? theme.secondary.opacity(0.3) : theme.primary.opacity(opacity))
                            .frame(width: 10, height: 10)
                    }
                    Text("More")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.mutedForeground)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            Spacer(minLength: 14)
        }
        .dashboardCard()
    }

    private func groupByWeek() -> [[HeatmapDay?]] {
        let cal = Calendar.current
        var weeks: [[HeatmapDay?]] = []
        var currentWeek: [HeatmapDay?] = Array(repeating: nil, count: 7)

        for day in data {
            // Monday=0 ... Sunday=6
            let weekday = cal.component(.weekday, from: day.date)
            let index = (weekday + 5) % 7 // Convert: Sun=1 -> 6, Mon=2 -> 0, ...
            currentWeek[index] = day

            if index == 6 {
                weeks.append(currentWeek)
                currentWeek = Array(repeating: nil, count: 7)
            }
        }

        // Add last partial week
        if currentWeek.contains(where: { $0 != nil }) {
            weeks.append(currentWeek)
        }

        return weeks
    }

    private func dayForIndex(week: [HeatmapDay?], dayIndex: Int) -> HeatmapDay? {
        guard dayIndex < week.count else { return nil }
        return week[dayIndex]
    }

    private func weekStartLabel(_ week: [HeatmapDay?]) -> String {
        guard let firstDay = week.compactMap({ $0 }).first else { return "" }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: firstDay.date)
        let mondayOffset = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -mondayOffset, to: firstDay.date) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: monday)
    }

    private func heatmapColor(for day: HeatmapDay?) -> Color {
        guard let day = day else { return theme.secondary.opacity(0.15) }
        let hours = Double(day.totalSeconds) / 3600.0
        if hours < 0.1 { return theme.secondary.opacity(0.3) }
        if hours < 2 { return theme.primary.opacity(0.15) }
        if hours < 4 { return theme.primary.opacity(0.35) }
        if hours < 6 { return theme.primary.opacity(0.6) }
        return theme.primary.opacity(0.9)
    }

    private func heatmapTooltip(for day: HeatmapDay?) -> String {
        guard let day = day else { return "No data" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        let hours = Double(day.totalSeconds) / 3600.0
        return "\(fmt.string(from: day.date)): \(String(format: "%.1f", hours)) hours"
    }
}
#endif
