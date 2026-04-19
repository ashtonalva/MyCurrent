import Foundation

struct SleepLog: Codable {
    var bedtime: String
    var wakeTime: String
}

struct CaffeineEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var time: String
    var mg: Int
    var label: String
}

struct ScheduleBlock: Codable, Identifiable {
    var id: UUID = UUID()
    var day: String
    var start: String
    var end: String
    var label: String
}

struct CrashWindow {
    var start: String
    var end: String
    var reason: String
}

struct DashboardState {
    var currentEnergy: Int
    var peakWindow: String
    var crashWindow: CrashWindow?
    var sleepScore: Int
    var caffeineStatus: String
    var recommendations: [String]
}
