import Foundation
import Combine

final class LocalStore: ObservableObject {
    @Published var sleepLog: SleepLog
    @Published var caffeineEntries: [CaffeineEntry]
    @Published var scheduleBlocks: [ScheduleBlock]
    @Published var healthProfile: HealthProfile
    @Published var feedbackHistory: [UserScoreFeedback]
    @Published var lastMLInputExportAt: Date?
    @Published var metricHistory: [DailyMetricSnapshot]

    private let sleepKey = "mycurrent.sleep"
    private let caffeineKey = "mycurrent.caffeine"
    private let scheduleKey = "mycurrent.schedule"
    private let profileKey = "mycurrent.healthProfile"
    private let feedbackKey = "mycurrent.feedback"
    private let mlInputExportKey = "mycurrent.mlInputExportAt"
    private let metricHistoryKey = "mycurrent.metricHistory14"
    private let mlBridgeService = MLBridgeService()

    init() {
        self.sleepLog = LocalStore.load(key: sleepKey, fallback: SleepLog(bedtime: "01:30", wakeTime: "07:30", quality: 65))
        self.caffeineEntries = LocalStore.load(key: caffeineKey, fallback: [
            CaffeineEntry(time: "11:00", mg: 200, label: "Energy Drink")
        ])
        self.scheduleBlocks = LocalStore.load(key: scheduleKey, fallback: [
            ScheduleBlock(day: "Mon", start: "13:00", end: "16:00", label: "Study Block")
        ])
        self.healthProfile = LocalStore.load(key: profileKey, fallback: HealthProfile(age: 20, screenTimeMinutes: 240, activityMinutes: 40))
        self.feedbackHistory = LocalStore.load(key: feedbackKey, fallback: [])
        self.lastMLInputExportAt = LocalStore.load(key: mlInputExportKey, fallback: nil)
        self.metricHistory = LocalStore.load(key: metricHistoryKey, fallback: [])
    }

    func saveSleep() {
        LocalStore.save(value: sleepLog, key: sleepKey)
        refreshMLBridgeInput()
        refreshMetricSnapshot()
    }

    func saveCaffeine() {
        LocalStore.save(value: caffeineEntries, key: caffeineKey)
        refreshMLBridgeInput()
        refreshMetricSnapshot()
    }

    func saveSchedule() {
        LocalStore.save(value: scheduleBlocks, key: scheduleKey)
        refreshMLBridgeInput()
        refreshMetricSnapshot()
    }

    func saveHealthProfile() {
        LocalStore.save(value: healthProfile, key: profileKey)
        refreshMLBridgeInput()
        refreshMetricSnapshot()
    }

    func saveFeedback() {
        LocalStore.save(value: feedbackHistory, key: feedbackKey)
    }

    func submitFeedback(predictedScore: Int, userReportedScore: Int) {
        feedbackHistory.append(
            UserScoreFeedback(
                timestamp: Date(),
                predictedScore: predictedScore,
                userReportedScore: userReportedScore
            )
        )
        if feedbackHistory.count > 30 {
            feedbackHistory = Array(feedbackHistory.suffix(30))
        }
        saveFeedback()
    }

    func removeFeedback(id: UUID) {
        feedbackHistory.removeAll { $0.id == id }
        saveFeedback()
    }

    /// Upsert today’s snapshot for Human Δ visuals (call after saves / on dashboard appear).
    func refreshMetricSnapshot() {
        let sleepHours = estimateSleepHours(from: sleepLog)
        let caffeineMg = caffeineEntries.reduce(0) { $0 + $1.mg }
        let stress = HumanDeltaVisualContext.stressProxy(
            caffeineTotalMg: caffeineMg,
            scheduleBlockCount: scheduleBlocks.count,
            screenMinutes: healthProfile.screenTimeMinutes
        )
        let day = DailyMetricSnapshot.dayId()
        var next = metricHistory
        let snap = DailyMetricSnapshot(
            dayId: day,
            sleepHours: sleepHours,
            stressProxy: stress,
            activityMinutes: healthProfile.activityMinutes
        )
        if let idx = next.firstIndex(where: { $0.dayId == day }) {
            next[idx] = snap
        } else {
            next.append(snap)
            next.sort { $0.dayId < $1.dayId }
            if next.count > 14 {
                next = Array(next.suffix(14))
            }
        }
        metricHistory = next
        LocalStore.save(value: metricHistory, key: metricHistoryKey)
    }

    private func estimateSleepHours(from sleep: SleepLog) -> Double {
        HumanDeltaScheduleAdvisor.estimatedSleepHours(sleep: sleep)
    }

    private static func load<T: Codable>(key: String, fallback: T) -> T {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode(T.self, from: data)
        else {
            return fallback
        }
        return decoded
    }

    private static func save<T: Codable>(value: T, key: String) {
        guard let encoded = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    private func refreshMLBridgeInput() {
        do {
            let export = try mlBridgeService.exportInput(
                sleep: sleepLog,
                caffeine: caffeineEntries,
                profile: healthProfile
            )
            lastMLInputExportAt = export.exportedAt
            LocalStore.save(value: export.exportedAt, key: mlInputExportKey)
        } catch {
            // Keep app flow resilient if bridge write fails.
        }
    }
}
