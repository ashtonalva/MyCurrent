import Foundation

/// One row per calendar day for rolling Human Δ visuals (aligned with backend feature rows).
struct DailyMetricSnapshot: Codable, Identifiable, Equatable {
    /// ISO date only `yyyy-MM-dd` in UTC for stable keys.
    var dayId: String
    var sleepHours: Double
    /// 0–10 heuristic from caffeine, schedule load, screen time.
    var stressProxy: Double
    var activityMinutes: Int

    var id: String { dayId }

    static func dayId(for date: Date = Date()) -> String {
        let c = Calendar.current
        let comps = c.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
