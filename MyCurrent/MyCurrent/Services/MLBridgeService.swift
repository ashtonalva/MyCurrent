import Foundation

struct MLLoadedPrediction {
    let score: Int
    let generatedAt: Date?
}

final class MLBridgeService {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let inputFilename = "ml_input.json"
    private let outputFilename = "ml_output.json"

    func exportInput(
        sleep: SleepLog,
        caffeine: [CaffeineEntry],
        profile: HealthProfile
    ) throws -> (url: URL, exportedAt: Date) {
        let input = buildInput(sleep: sleep, caffeine: caffeine, profile: profile)
        let url = documentsDirectory().appendingPathComponent(inputFilename)
        let data = try encoder.encode(input)
        try data.write(to: url, options: .atomic)
        return (url, Date())
    }

    func loadPrediction() throws -> MLLoadedPrediction? {
        let outputURL = documentsDirectory().appendingPathComponent(outputFilename)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            let data = try Data(contentsOf: outputURL)
            let payload = try decoder.decode(MLBridgeOutput.self, from: data)
            return MLLoadedPrediction(
                score: Int(payload.predicted_health_score.rounded()),
                generatedAt: parseGeneratedAt(payload.generated_at)
            )
        }

        if let bundled = Bundle.main.url(forResource: "ml_latest_prediction", withExtension: "json") {
            let data = try Data(contentsOf: bundled)
            let payload = try decoder.decode(MLBridgeOutput.self, from: data)
            return MLLoadedPrediction(
                score: Int(payload.predicted_health_score.rounded()),
                generatedAt: parseGeneratedAt(payload.generated_at)
            )
        }

        return nil
    }

    private func buildInput(
        sleep: SleepLog,
        caffeine: [CaffeineEntry],
        profile: HealthProfile
    ) -> MLBridgeInput {
        let sleepHours = estimateSleepHours(bedtime: sleep.bedtime, wakeTime: sleep.wakeTime)
        let caffeineTotal = Double(caffeine.reduce(0) { $0 + $1.mg })
        let timeBeforeBed = estimateTimeBeforeBedHours(caffeine: caffeine, bedtime: sleep.bedtime)
        let sleepDebt = max(0, 8.0 - sleepHours)
        let recovery = min(1.2, sleepHours / 8.0)
        let consistency = 0.8
        let screenHours = Double(profile.screenTimeMinutes) / 60.0
        let steps = max(1000, Double(profile.activityMinutes) * 120.0)
        let activityBalance = max(0.0, min(1.0, 1.0 - abs(Double(profile.activityMinutes) - 60.0) / 60.0))
        let circadianAlignment = estimateCircadianAlignment(bedtime: sleep.bedtime, wakeTime: sleep.wakeTime)

        return MLBridgeInput(
            sleep_index_rate: Double(sleep.quality) / 100.0,
            sleep_duration_hours: sleepHours,
            caffeine_intake: caffeineTotal,
            time_before_bed_hours: timeBeforeBed,
            screen_time: screenHours,
            physical_activity_minutes: Double(profile.activityMinutes),
            steps: steps,
            activity_minutes: Double(profile.activityMinutes),
            bed_time: toHour(sleep.bedtime),
            wake_time: toHour(sleep.wakeTime),
            sleep_consistency_score: consistency,
            sleep_debt: sleepDebt,
            recovery_index: recovery,
            caffeine_x_time_before_sleep: caffeineTotal * timeBeforeBed,
            activity_balance: activityBalance,
            circadian_alignment: circadianAlignment,
            age: Double(profile.age)
        )
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func estimateSleepHours(bedtime: String, wakeTime: String) -> Double {
        let bed = minutes(from: bedtime)
        let wake = minutes(from: wakeTime)
        let duration = wake >= bed ? wake - bed : (24 * 60 - bed) + wake
        return Double(duration) / 60.0
    }

    private func estimateTimeBeforeBedHours(caffeine: [CaffeineEntry], bedtime: String) -> Double {
        guard let latest = caffeine.max(by: { minutes(from: $0.time) < minutes(from: $1.time) }) else {
            return 8
        }
        let bed = minutes(from: bedtime)
        let caff = minutes(from: latest.time)
        let diff = bed >= caff ? bed - caff : (24 * 60 - caff) + bed
        return max(0.5, Double(diff) / 60.0)
    }

    private func estimateCircadianAlignment(bedtime: String, wakeTime: String) -> Double {
        let bedHour = toHour(bedtime)
        let wakeHour = toHour(wakeTime)
        let midSleep = (bedHour + ((wakeHour + 24).truncatingRemainder(dividingBy: 24))) / 2.0
        return max(0.0, min(1.0, 1.0 - abs(midSleep - 3.0) / 12.0))
    }

    private func toHour(_ hhmm: String) -> Double {
        let mins = minutes(from: hhmm)
        return Double(mins) / 60.0
    }

    private func minutes(from hhmm: String) -> Int {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0 }
        return (parts[0] * 60) + parts[1]
    }
    
    private func parseGeneratedAt(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }
}
