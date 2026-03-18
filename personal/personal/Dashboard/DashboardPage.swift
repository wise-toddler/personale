#if os(macOS)
import Charts
import SwiftUI

// MARK: - Dashboard Page

struct DashboardPage: View {
    @Environment(\.theme) private var theme
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppMetrics.cardGap) {
                DateNavigator(
                    dateText: viewModel.displayDate,
                    isToday: viewModel.isToday,
                    isLoading: viewModel.isLoading,
                    onPrevious: { viewModel.goToPreviousDay() },
                    onNext: { viewModel.goToNextDay() },
                    onToday: { viewModel.goToToday() }
                )

                // Hero metrics row
                HeroMetricsRow(
                    workHours: viewModel.workHours,
                    breakTimerText: viewModel.breakTimerText,
                    breakToWorkRatio: viewModel.breakToWorkRatio,
                    timeBreakdown: viewModel.timeBreakdown
                )

                // Timeline (full width)
                TimelineCard(data: viewModel.timeline)

                // Workblocks + Activity row
                HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                    if DashboardFeatures.showWorkblocks {
                        WorkblocksCard(data: viewModel.workblocks)
                            .frame(maxWidth: .infinity)
                    }
                    ActivityLogCard(data: viewModel.activityLog)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(AppMetrics.contentPadding)
        }
        .onAppear { viewModel.startRefreshing() }
        .onDisappear { viewModel.stopRefreshing() }
    }
}

// MARK: - Hero Metrics Row

struct HeroMetricsRow: View {
    let workHours: MockData.WorkHours
    let breakTimerText: String
    let breakToWorkRatio: String
    let timeBreakdown: [MockData.TimeBreakdownEntry]
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: AppMetrics.cardGap) {
            // Big hours metric + activity ring
            HStack(spacing: 24) {
                // Activity ring
                CircularProgress(
                    value: workHours.percentOfDay,
                    size: 72,
                    strokeWidth: 6,
                    color: theme.primary
                )
                .overlay {
                    Text("\(Int(workHours.percentOfDay))%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.foreground)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(workHours.totalWorked)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.foreground)
                    Text("of \(workHours.targetHours) target")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.mutedForeground)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dashboardCard()

            // Break timer
            if DashboardFeatures.showBreakTimer {
                VStack(alignment: .leading, spacing: 4) {
                    SectionTitle(text: "Since Last Break")
                    Text(breakTimerText)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.foreground)
                    HStack(spacing: 4) {
                        Text("Ratio")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.mutedForeground)
                        Text(breakToWorkRatio)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.accent)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dashboardCard()
            }

            // Category breakdown (compact bar chart)
            CategoryBarCard(data: timeBreakdown)
                .frame(width: 320)
        }
    }
}

// MARK: - Category Bar Card (Swift Charts)

struct CategoryBarCard: View {
    let data: [MockData.TimeBreakdownEntry]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Categories")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            if !data.isEmpty {
                Chart(Array(data.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("Time", item.percent),
                        y: .value("Category", item.category)
                    )
                    .foregroundStyle(Color(hex: item.colorHex))
                    .cornerRadius(3)
                    .annotation(position: .trailing, spacing: 6) {
                        Text(item.time)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(theme.mutedForeground)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let cat = value.as(String.self) {
                                Text(cat)
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.foreground)
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot.background(Color.clear)
                }
                .frame(height: max(CGFloat(data.count) * 28, 80))
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 16)
        }
        .dashboardCard()
    }
}

// MARK: - Timeline Card (Swift Charts)

struct TimelineCard: View {
    let data: [MockData.TimelineBlock]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Timeline")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            if data.isEmpty {
                Text("No activity recorded")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                Chart(Array(data.enumerated()), id: \.offset) { _, block in
                    RectangleMark(
                        xStart: .value("Start", block.start),
                        xEnd: .value("End", block.end),
                        y: .value("Activity", "Day")
                    )
                    .foregroundStyle(CategoryColors.color(for: block.type).opacity(0.85))
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 2)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(theme.border)
                        AxisValueLabel {
                            if let hour = value.as(Double.self) {
                                Text(hourLabel(Int(hour)))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(theme.mutedForeground)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartPlotStyle { plot in
                    plot.background(theme.secondary.opacity(0.3))
                        .cornerRadius(4)
                }
                .frame(height: 44)
                .padding(.horizontal, 16)
            }

            // Category legend
            if !data.isEmpty {
                HStack(spacing: 12) {
                    let categories = uniqueCategories()
                    ForEach(categories, id: \.self) { cat in
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
        return data.compactMap { block in
            let cat = block.type
            if seen.contains(cat) { return nil }
            seen.insert(cat)
            return cat
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 || hour == 24 { return "12a" }
        if hour == 12 { return "12p" }
        if hour < 12 { return "\(hour)a" }
        return "\(hour - 12)p"
    }
}

// MARK: - Workblocks Card

struct WorkblocksCard: View {
    let data: [MockData.Workblock]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Workblocks")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, block in
                        HStack {
                            Text(block.time)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 44, alignment: .leading)

                            Text(block.task)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(block.duration)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                        .padding(.leading, 12)
                        .padding(.trailing, 4)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(CategoryColors.color(for: block.task))
                                .frame(width: 3)
                        }
                    }
                }
            }
            .frame(height: 280)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}

// MARK: - Activity Log Card

struct ActivityLogCard: View {
    let data: [MockData.ActivityEntry]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Activity")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 0) {
                            Text(entry.time)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 64, alignment: .leading)

                            Text(entry.app)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 100, alignment: .leading)

                            Text(entry.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.mutedForeground)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }
                }
            }
            .frame(height: 280)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}

// MARK: - Projects Card (hidden by feature flag, kept for future)

struct ProjectsCard: View {
    let data: [MockData.Project]
    @Environment(\.theme) private var theme

    private func projectColor(_ name: String) -> Color {
        switch name {
        case "purple": theme.chartPurple
        case "pink": theme.chartPink
        case "teal": theme.chartTeal
        default: theme.chartGray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Projects")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 12) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, project in
                    HStack(spacing: 12) {
                        Text("\(project.percent)%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(theme.mutedForeground)
                            .frame(width: 32, alignment: .trailing)

                        Text(project.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.foreground)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.secondary.opacity(0.8))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(projectColor(project.color))
                                .frame(width: CGFloat(project.percent) / 100.0 * 112, height: 6)
                        }
                        .frame(width: 112)

                        Text(project.time)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(theme.mutedForeground)
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}

// MARK: - Scores Card (hidden by feature flag, kept for future)

struct ScoresCard: View {
    let data: MockData.ScoreSet
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Scores")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            HStack {
                Spacer()
                scoreItem(label: "Focus", percent: data.focus.percent, time: data.focus.time,
                          color: theme.chartCyan, labelColor: theme.accent)
                Spacer()
                scoreItem(label: "Meetings", percent: data.meetings.percent, time: data.meetings.time,
                          color: theme.chartPurple, labelColor: theme.primary)
                Spacer()
                scoreItem(label: "Breaks", percent: data.breaks.percent, time: data.breaks.time,
                          color: theme.chartTeal, labelColor: theme.chartTeal)
                Spacer()
            }
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }

    private func scoreItem(label: String, percent: Int, time: String, color: Color, labelColor: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                CircularProgress(value: Double(percent), size: 52, strokeWidth: 4, color: color)
                Text("\(percent)%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.foreground)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(labelColor)
            Text(time)
                .font(.system(size: 9))
                .foregroundStyle(theme.mutedForeground)
        }
    }
}

// MARK: - Time Breakdown Card (kept for backward compat, replaced by CategoryBarCard)

struct TimeBreakdownCard: View {
    let data: [MockData.TimeBreakdownEntry]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Time Breakdown")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 8) {
                            Text("\(item.percent)%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 28, alignment: .trailing)

                            Text(item.category)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 112, alignment: .leading)
                                .lineLimit(1)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(theme.secondary.opacity(0.6))
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(Color(hex: item.colorHex))
                                        .frame(width: min(CGFloat(item.percent) * 2.2 / 100 * geo.size.width, geo.size.width))
                                }
                            }
                            .frame(height: 5)

                            Text(item.time)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 64, alignment: .trailing)
                        }
                    }
                }
            }
            .frame(height: 210)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}
#endif
