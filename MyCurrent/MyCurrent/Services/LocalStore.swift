import Foundation
import Combine

final class LocalStore: ObservableObject {
    @Published var sleepLog: SleepLog
    @Published var caffeineEntries: [CaffeineEntry]
    @Published var scheduleBlocks: [ScheduleBlock]
    @Published var healthProfile: HealthProfile
    @Published var feedbackHistory: [UserScoreFeedback]
    @Published var lastMLInputExportAt: Date?

    private let sleepKey = "mycurrent.sleep"
    private let caffeineKey = "mycurrent.caffeine"
    private let scheduleKey = "mycurrent.schedule"
    private let profileKey = "mycurrent.healthProfile"
    private let feedbackKey = "mycurrent.feedback"
    private let mlInputExportKey = "mycurrent.mlInputExportAt"
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
    }

    func saveSleep() {
        LocalStore.save(value: sleepLog, key: sleepKey)
        refreshMLBridgeInput()
    }

    func saveCaffeine() {
        LocalStore.save(value: caffeineEntries, key: caffeineKey)
        refreshMLBridgeInput()
    }

    func saveSchedule() {
        LocalStore.save(value: scheduleBlocks, key: scheduleKey)
        refreshMLBridgeInput()
    }

    func saveHealthProfile() {
        LocalStore.save(value: healthProfile, key: profileKey)
        refreshMLBridgeInput()
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
