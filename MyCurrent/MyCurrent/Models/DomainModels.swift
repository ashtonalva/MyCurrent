import Foundation

struct SleepLog: Codable {
    var bedtime: String
    var wakeTime: String
    var quality: Int
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

struct HealthProfile: Codable {
    var age: Int
    var screenTimeMinutes: Int
    var activityMinutes: Int
}

struct UserScoreFeedback: Codable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date
    var predictedScore: Int
    var userReportedScore: Int
}

struct EnergyPoint: Identifiable {
    var id: Int { minuteOfDay }
    var minuteOfDay: Int
    var timeLabel: String
    var score: Int
}

struct CaffeineMarker: Identifiable {
    var id = UUID()
    var minuteOfDay: Int
    var timeLabel: String
    var mg: Int
}

struct MLBridgeInput: Codable {
    var sleep_index_rate: Double
    var sleep_duration_hours: Double
    var caffeine_intake: Double
    var time_before_bed_hours: Double
    var screen_time: Double
    var physical_activity_minutes: Double
    var steps: Double
    var activity_minutes: Double
    var bed_time: Double
    var wake_time: Double
    var sleep_consistency_score: Double
    var sleep_debt: Double
    var recovery_index: Double
    var caffeine_x_time_before_sleep: Double
    var activity_balance: Double
    var circadian_alignment: Double
    var age: Double
}

struct MLBridgeOutput: Codable {
    var predicted_health_score: Double
    var model: String?
    var generated_at: String?
}

struct DashboardState {
    var currentEnergy: Int
    var predictedHealthScore: Int
    var personalizedHealthScore: Int
    var userDeltaBias: Int
    var oceanState: String
    var peakWindow: String
    var crashWindow: CrashWindow?
    var sleepScore: Int
    var caffeineStatus: String
    var recommendations: [String]
    var energyPoints: [EnergyPoint]
    var caffeineMarkers: [CaffeineMarker]
}
