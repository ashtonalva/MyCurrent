import Foundation

final class LocalStore: ObservableObject {
    @Published var sleepLog: SleepLog
    @Published var caffeineEntries: [CaffeineEntry]
    @Published var scheduleBlocks: [ScheduleBlock]

    private let sleepKey = "mycurrent.sleep"
    private let caffeineKey = "mycurrent.caffeine"
    private let scheduleKey = "mycurrent.schedule"

    init() {
        self.sleepLog = LocalStore.load(key: sleepKey, fallback: SleepLog(bedtime: "01:30", wakeTime: "07:30"))
        self.caffeineEntries = LocalStore.load(key: caffeineKey, fallback: [
            CaffeineEntry(time: "11:00", mg: 200, label: "Energy Drink")
        ])
        self.scheduleBlocks = LocalStore.load(key: scheduleKey, fallback: [
            ScheduleBlock(day: "Mon", start: "13:00", end: "16:00", label: "Study Block")
        ])
    }

    func saveSleep() {
        LocalStore.save(value: sleepLog, key: sleepKey)
    }

    func saveCaffeine() {
        LocalStore.save(value: caffeineEntries, key: caffeineKey)
    }

    func saveSchedule() {
        LocalStore.save(value: scheduleBlocks, key: scheduleKey)
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
}
