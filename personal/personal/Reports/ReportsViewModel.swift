#if os(macOS)
import Combine
import Foundation
import SwiftUI

// MARK: - Data Types

struct WeeklyDayEntry: Identifiable {
    let id: String
    let date: String
    let dayLabel: String
    let totalSeconds: Int
    let categories: [WeeklyCategoryEntry]
}

struct WeeklyCategoryEntry: Identifiable {
    let id: String
    let category: String
    let seconds: Int
}

struct HeatmapDay: Identifiable {
    let id: Date
    let date: Date
    let totalSeconds: Int
}

// MARK: - Reports ViewModel

@MainActor
class ReportsViewModel: ObservableObject {
    @Published var weeklyData: [WeeklyDayEntry] = []
    @Published var heatmapData: [HeatmapDay] = []
    @Published var weekEndDate: Date = Date()
    @Published var isLoading = false

    private let stats = StatsEngine.shared

    private static let dateFmt: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    // MARK: - Navigation

    func goToPreviousWeek() {
        weekEndDate = Calendar.current.date(byAdding: .day, value: -7, to: weekEndDate) ?? weekEndDate
        fetchAll()
    }

    func goToNextWeek() {
        let next = Calendar.current.date(byAdding: .day, value: 7, to: weekEndDate) ?? weekEndDate
        if next <= Date() {
            weekEndDate = next
        } else {
            weekEndDate = Date()
        }
        fetchAll()
    }

    func goToCurrentWeek() {
        weekEndDate = Date()
        fetchAll()
    }

    var isCurrentWeek: Bool {
        Calendar.current.isDateInToday(weekEndDate)
    }

    // MARK: - Week Label

    var weekLabel: String {
        let cal = Calendar.current
        let end = cal.startOfDay(for: weekEndDate)
        guard let start = cal.date(byAdding: .day, value: -6, to: end) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let yearFmt = DateFormatter()
        yearFmt.dateFormat = ", yyyy"
        return "\(fmt.string(from: start)) - \(fmt.string(from: end))\(yearFmt.string(from: end))"
    }

    // MARK: - Computed Properties

    var weeklyTotal: Int {
        weeklyData.reduce(0) { $0 + $1.totalSeconds }
    }

    var dailyAverage: Int {
        let daysWithData = weeklyData.filter { $0.totalSeconds > 0 }.count
        guard daysWithData > 0 else { return 0 }
        return weeklyTotal / daysWithData
    }

    var topCategory: String {
        var catTotals: [String: Int] = [:]
        for day in weeklyData {
            for cat in day.categories {
                catTotals[cat.category, default: 0] += cat.seconds
            }
        }
        return catTotals.max(by: { $0.value < $1.value })?.key ?? "—"
    }

    var mostProductiveDay: String {
        guard let best = weeklyData.max(by: { $0.totalSeconds < $1.totalSeconds }),
              best.totalSeconds > 0 else { return "—" }
        return best.dayLabel
    }

    // MARK: - Data Fetching

    func fetchAll() {
        isLoading = true
        let dateStr = Self.dateFmt.string(from: weekEndDate)
        let weekly = stats.getWeeklyStats(endDate: dateStr)
        let heatmap = stats.getHeatmapData(weeks: 12)

        weeklyData = weekly.map { day in
            WeeklyDayEntry(
                id: day.date,
                date: day.date,
                dayLabel: day.dayLabel,
                totalSeconds: day.totalSeconds,
                categories: day.categories.map { cat in
                    WeeklyCategoryEntry(id: cat.category, category: cat.category, seconds: cat.seconds)
                }
            )
        }

        heatmapData = heatmap.map { day in
            HeatmapDay(id: day.date, date: day.date, totalSeconds: day.totalSeconds)
        }

        isLoading = false
    }

    // MARK: - Helpers

    func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        if hours > 0 { return "\(hours) hr \(mins) min" }
        return "\(mins) min"
    }

    func formatHours(_ totalSeconds: Int) -> String {
        let hours = Double(totalSeconds) / 3600.0
        return String(format: "%.1f hr", hours)
    }
}
#endif
