import Foundation

enum InputValidator {
    static func isValidTime(_ value: String) -> Bool {
        minutes(from: value) != nil
    }

    static func minutes(from value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour * 60) + minute
    }

    static func isValidCaffeine(_ value: String) -> Bool {
        guard let mg = Int(value) else { return false }
        return (1...500).contains(mg)
    }
}
