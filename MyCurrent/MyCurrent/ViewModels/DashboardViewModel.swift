import Foundation

struct DashboardCalculator {
    static func buildState(
        sleep: SleepLog,
        caffeine: [CaffeineEntry],
        schedule: [ScheduleBlock],
        profile: HealthProfile,
        feedbackHistory: [UserScoreFeedback],
        mlPredictedScore: Int? = nil
    ) -> DashboardState {
        let sleepHours = estimateSleepHours(bedtime: sleep.bedtime, wakeTime: sleep.wakeTime)
        let sleepScore = max(0, min(100, Int((sleepHours / 8.0) * 100)))
        let totalCaffeine = caffeine.reduce(0) { $0 + $1.mg }
        let hasLargeDose = caffeine.contains { $0.mg >= 180 }
        let busyDay = schedule.count >= 3
        let ruleBasedPredictedScore = predictedScore(
            sleepHours: sleepHours,
            sleepQuality: sleep.quality,
            totalCaffeine: totalCaffeine,
            profile: profile
        )
        let predictedHealthScore = mlPredictedScore ?? ruleBasedPredictedScore
        let userDeltaBias = calculateUserDeltaBias(feedbackHistory: feedbackHistory)
        let personalizedHealthScore = clamp(predictedHealthScore + userDeltaBias, min: 0, max: 100)
        let caffeineMarkers = buildCaffeineMarkers(caffeine)
        let energyPoints = buildEnergyTimeline(
            predictedHealthScore: predictedHealthScore,
            sleepHours: sleepHours,
            caffeine: caffeine
        )
        let currentEnergy = currentEnergyValue(from: energyPoints)
        let peakWindow = calculatePeakWindow(from: energyPoints)

        let crash: CrashWindow? = (sleepHours < 6.5 && hasLargeDose) || (sleepHours < 6 && busyDay)
            ? CrashWindow(start: "3:00 PM", end: "4:30 PM", reason: "Short sleep + stimulant drop")
            : nil

        let recommendations = buildRecommendations(
            sleepHours: sleepHours,
            sleepQuality: sleep.quality,
            totalCaffeine: totalCaffeine,
            profile: profile
        )

        return DashboardState(
            currentEnergy: currentEnergy,
            predictedHealthScore: predictedHealthScore,
            personalizedHealthScore: personalizedHealthScore,
            userDeltaBias: userDeltaBias,
            oceanState: oceanState(for: personalizedHealthScore),
            peakWindow: peakWindow,
            crashWindow: crash,
            sleepScore: sleepScore,
            caffeineStatus: caffeineStatus(totalMg: totalCaffeine),
            recommendations: recommendations,
            energyPoints: energyPoints,
            caffeineMarkers: caffeineMarkers
        )
    }

    private static func caffeineStatus(totalMg: Int) -> String {
        switch totalMg {
        case 0..<120:
            return "Safe"
        case 120..<260:
            return "Watch"
        default:
            return "High"
        }
    }

    private static func estimateSleepHours(bedtime: String, wakeTime: String) -> Double {
        let bed = minutes(from: bedtime)
        let wake = minutes(from: wakeTime)
        let duration = wake >= bed ? wake - bed : (24 * 60 - bed) + wake
        return Double(duration) / 60.0
    }

    private static func minutes(from hhmm: String) -> Int {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0 }
        return (parts[0] * 60) + parts[1]
    }

    private static func predictedScore(
        sleepHours: Double,
        sleepQuality: Int,
        totalCaffeine: Int,
        profile: HealthProfile
    ) -> Int {
        var score = 70
        score += Int((sleepHours - 7.0) * 7.0)
        score += Int(Double(sleepQuality - 60) * 0.35)
        score -= min(18, max(0, (totalCaffeine - 120) / 15))
        score -= min(16, profile.screenTimeMinutes / 40)
        score += min(15, profile.activityMinutes / 12)
        if profile.activityMinutes < 20 {
            score -= 8
        } else if profile.activityMinutes > 150 {
            score -= 5
        }
        if profile.age >= 26 {
            score -= 2
        }
        return clamp(score, min: 0, max: 100)
    }

    private static func calculateUserDeltaBias(feedbackHistory: [UserScoreFeedback]) -> Int {
        let recent = feedbackHistory.suffix(7)
        guard !recent.isEmpty else { return 0 }
        let deltas = recent.map { $0.userReportedScore - $0.predictedScore }
        let average = deltas.reduce(0, +) / deltas.count
        return clamp(average, min: -15, max: 15)
    }

    private static func oceanState(for score: Int) -> String {
        switch score {
        case 80...100: return "Calm Waters"
        case 60..<80: return "Steady Current"
        case 40..<60: return "Choppy Tide"
        default: return "Storm Warning"
        }
    }

    private static func buildRecommendations(
        sleepHours: Double,
        sleepQuality: Int,
        totalCaffeine: Int,
        profile: HealthProfile
    ) -> [String] {
        var items: [String] = []
        if sleepHours < 7 {
            items.append("Target 7.5h tonight. Try a bedtime around 11:15 PM.")
        }
        if sleepQuality < 65 {
            items.append("Start a 30-minute wind-down with low light before bed.")
        }
        if totalCaffeine > 200 {
            items.append("Keep caffeine under 200mg and avoid intake after 2:30 PM.")
        }
        if profile.screenTimeMinutes > 240 {
            items.append("Cut evening screen time by 30 minutes to improve recovery.")
        }
        if profile.activityMinutes < 30 {
            items.append("Add a 20-minute walk to stabilize your daytime energy.")
        }
        if items.isEmpty {
            items.append("Great balance today. Keep your sleep and activity timing consistent.")
        }
        return items
    }

    private static func clamp(_ value: Int, min minValue: Int, max maxValue: Int) -> Int {
        Swift.max(minValue, Swift.min(maxValue, value))
    }

    private static func buildEnergyTimeline(
        predictedHealthScore: Int,
        sleepHours: Double,
        caffeine: [CaffeineEntry]
    ) -> [EnergyPoint] {
        var points: [EnergyPoint] = []
        let baseLevel = max(35, min(88, Int(Double(predictedHealthScore) * 0.85)))

        for minute in stride(from: 8 * 60, through: 22 * 60, by: 30) {
            let circadian = circadianAdjustment(minuteOfDay: minute)
            let caffeineBoost = caffeineContribution(at: minute, caffeine: caffeine)
            let sleepPenalty = sleepHours < 6.5 ? -8 : 0
            let score = clamp(baseLevel + circadian + caffeineBoost + sleepPenalty, min: 0, max: 100)
            points.append(
                EnergyPoint(
                    minuteOfDay: minute,
                    timeLabel: timeLabel(from: minute),
                    score: score
                )
            )
        }

        return points
    }

    private static func circadianAdjustment(minuteOfDay: Int) -> Int {
        let hour = Double(minuteOfDay) / 60.0
        switch hour {
        case 8..<11:
            return 8
        case 11..<13:
            return 12
        case 13..<16:
            return -7
        case 16..<19:
            return 5
        case 19..<22:
            return -4
        default:
            return 0
        }
    }

    private static func caffeineContribution(at minute: Int, caffeine: [CaffeineEntry]) -> Int {
        var total = 0
        for entry in caffeine {
            let intakeMinute = minutes(from: entry.time)
            let delta = minute - intakeMinute
            guard delta >= 0 else { continue }

            let amplitude = min(28, entry.mg / 8)
            if (20...240).contains(delta) {
                let progress = Double(delta - 20) / 220.0
                total += Int(Double(amplitude) * (1.0 - abs(0.5 - progress)))
            } else if (241...360).contains(delta) {
                total -= Int(Double(amplitude) * 0.45)
            }
        }
        return total
    }

    private static func buildCaffeineMarkers(_ caffeine: [CaffeineEntry]) -> [CaffeineMarker] {
        caffeine.compactMap { entry in
            guard InputValidator.isValidTime(entry.time) else { return nil }
            let minute = minutes(from: entry.time)
            return CaffeineMarker(
                minuteOfDay: minute,
                timeLabel: timeLabel(from: minute),
                mg: entry.mg
            )
        }
    }

    private static func currentEnergyValue(from points: [EnergyPoint]) -> Int {
        guard !points.isEmpty else { return 50 }
        let now = Date()
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
        let nowMinute = (comps.hour ?? 12) * 60 + (comps.minute ?? 0)
        let nearest = points.min(by: { abs($0.minuteOfDay - nowMinute) < abs($1.minuteOfDay - nowMinute) })
        return nearest?.score ?? points.last?.score ?? 50
    }

    private static func calculatePeakWindow(from points: [EnergyPoint]) -> String {
        guard let peak = points.max(by: { $0.score < $1.score }) else {
            return "10:30 AM - 1:00 PM"
        }
        let start = max(8 * 60, peak.minuteOfDay - 60)
        let end = min(22 * 60, peak.minuteOfDay + 60)
        return "\(timeLabel(from: start)) - \(timeLabel(from: end))"
    }

    private static func timeLabel(from minuteOfDay: Int) -> String {
        let hour24 = minuteOfDay / 60
        let minute = minuteOfDay % 60
        let amPm = hour24 >= 12 ? "PM" : "AM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minute, amPm)
    }
}
