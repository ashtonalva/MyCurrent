import Foundation

struct DashboardCalculator {
    static func buildState(sleep: SleepLog, caffeine: [CaffeineEntry], schedule: [ScheduleBlock]) -> DashboardState {
        let sleepHours = estimateSleepHours(bedtime: sleep.bedtime, wakeTime: sleep.wakeTime)
        let sleepScore = max(0, min(100, Int((sleepHours / 8.0) * 100)))
        let totalCaffeine = caffeine.reduce(0) { $0 + $1.mg }
        let currentEnergy = max(15, min(95, sleepScore - 20 + min(25, totalCaffeine / 8)))
        let hasLargeDose = caffeine.contains { $0.mg >= 180 }
        let busyDay = schedule.count >= 3

        let crash: CrashWindow? = (sleepHours < 6.5 && hasLargeDose) || (sleepHours < 6 && busyDay)
            ? CrashWindow(start: "3:00 PM", end: "4:30 PM", reason: "Short sleep + stimulant drop")
            : nil

        let recommendations = [
            "Sleep by 11:20 PM for 7.5h before morning classes",
            "Avoid caffeine after 2:30 PM",
            "Take a 10-minute walk before your expected dip"
        ]

        return DashboardState(
            currentEnergy: currentEnergy,
            peakWindow: "10:30 AM - 1:00 PM",
            crashWindow: crash,
            sleepScore: sleepScore,
            caffeineStatus: caffeineStatus(totalMg: totalCaffeine),
            recommendations: recommendations
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
}
