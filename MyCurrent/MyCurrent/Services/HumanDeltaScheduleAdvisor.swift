import Foundation

/// Schedule + sleep analysis using the same **Human Delta** signal as the dashboard
/// (`userDeltaBias` from recent self-report vs predicted scores).
enum HumanDeltaScheduleAdvisor {

    /// On-device schedule + sleep heuristics (same Human Δ bias as Dashboard).
    static func localRestRecommendations(
        schedule: [ScheduleBlock],
        sleep: SleepLog,
        caffeine: [CaffeineEntry],
        profile: HealthProfile,
        feedbackHistory: [UserScoreFeedback],
        mlPredictedScore: Int?
    ) -> [String] {
        let state = DashboardCalculator.buildState(
            sleep: sleep,
            caffeine: caffeine,
            schedule: schedule,
            profile: profile,
            feedbackHistory: feedbackHistory,
            mlPredictedScore: mlPredictedScore
        )
        let bias = state.userDeltaBias
        let sleepHours = estimateSleepHours(bedtime: sleep.bedtime, wakeTime: sleep.wakeTime)
        let bedM = minutes(from: sleep.bedtime)

        var lines: [String] = []

        if feedbackHistory.isEmpty {
            lines.append(
                "Log a few check-ins on the Dashboard to unlock a personalized Human Delta—these hints use that signal once you have feedback."
            )
        } else {
            lines.append(deltaBiasSummary(bias: bias))
        }

        if schedule.isEmpty {
            lines.append("Add your classes and study blocks so we can spot gaps for real breaks.")
            return lines
        }

        let grouped = Dictionary(grouping: schedule) { $0.day }
        let dayOrder = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        for day in dayOrder {
            guard let blocks = grouped[day], !blocks.isEmpty else { continue }
            let parsed = blocks.compactMap { parseBlock($0) }.sorted { $0.start < $1.start }
            guard parsed.count >= 1 else { continue }

            for i in 0..<(parsed.count - 1) {
                let gap = parsed[i + 1].start - parsed[i].end
                if gap < 0 {
                    lines.append(
                        "\(day): times overlap or are out of order between \"\(parsed[i].label)\" and the next block—fix that before tuning rest."
                    )
                    continue
                }
                if gap < 20 {
                    lines.append(
                        "\(day): only \(gap) min between \(hhmm(parsed[i].end)) and your next block—try to carve at least 20–30 min when Human Delta is tight."
                    )
                } else if gap >= 50, bias <= 2 {
                    lines.append(
                        "\(day): ~\(gap) min free after \(hhmm(parsed[i].end))—use it off-screen; your schedule already protects some recovery time."
                    )
                }
            }

            if let last = parsed.last {
                let buffer = minutesToBedtime(fromLastActivityEnd: last.end, bedtime: bedM)
                if buffer < 75 && last.end >= 12 * 60 {
                    lines.append(
                        "\(day): last block ends \(hhmm(last.end)), about \(buffer) min before your usual bedtime—bias Human Delta toward recovery by ending heavy work earlier."
                    )
                }
            }

            let span = lastEnd(parsed) - parsed[0].start
            if span > 5 * 60, parsed.count >= 2 {
                let maxGap = maxGapBetween(parsed)
                if let mg = maxGap, mg < 25 {
                    lines.append(
                        "\(day): long stretch (\(hoursDesc(span))) with no real break—slot a \(bias <= 0 ? 25 : 15)–minute reset, especially while Human Delta is \(bias <= -3 ? "negative" : "neutral")."
                    )
                }
            }
        }

        if sleepHours < 7 {
            lines.append(
                "You’re targeting under ~7h sleep—keep daytime blocks from eating the buffer before \(sleep.bedtime); Human Delta can’t replace lost sleep debt."
            )
        }

        if lines.count > 6 {
            return Array(lines.prefix(6))
        }
        if lines.isEmpty {
            return [
                deltaBiasSummary(bias: bias),
                "Your week looks evenly spaced—keep one unplugged break mid-afternoon on your busiest day."
            ]
        }
        return lines
    }

    static func estimatedSleepHours(sleep: SleepLog) -> Double {
        estimateSleepHours(bedtime: sleep.bedtime, wakeTime: sleep.wakeTime)
    }

    // MARK: - Helpers

    private struct ParsedBlock {
        let start: Int
        let end: Int
        let label: String
    }

    private static func parseBlock(_ block: ScheduleBlock) -> ParsedBlock? {
        guard let s = InputValidator.minutes(from: block.start),
              let e = InputValidator.minutes(from: block.end),
              s < e else { return nil }
        return ParsedBlock(start: s, end: e, label: block.label)
    }

    private static func lastEnd(_ blocks: [ParsedBlock]) -> Int {
        blocks.map(\.end).max() ?? 0
    }

    private static func maxGapBetween(_ sorted: [ParsedBlock]) -> Int? {
        guard sorted.count >= 2 else { return nil }
        var best = 0
        for i in 0..<(sorted.count - 1) {
            let g = sorted[i + 1].start - sorted[i].end
            if g > best { best = g }
        }
        return best > 0 ? best : nil
    }

    private static func minutesToBedtime(fromLastActivityEnd lastEnd: Int, bedtime bed: Int) -> Int {
        if bed >= lastEnd {
            return bed - lastEnd
        }
        return (24 * 60 - lastEnd) + bed
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

    private static func hhmm(_ minuteOfDay: Int) -> String {
        let m = ((minuteOfDay % (24 * 60)) + (24 * 60)) % (24 * 60)
        let h = m / 60
        let min = m % 60
        return String(format: "%02d:%02d", h, min)
    }

    private static func hoursDesc(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private static func deltaBiasSummary(bias: Int) -> String {
        switch bias {
        case ..<(-7):
            return "Human Δ is strongly negative—you often feel below what the model expects, so treat open gaps as mandatory rest, not optional."
        case (-7)...(-3):
            return "Human Δ runs low: pack in short recovery between blocks before your energy tanks."
        case (-2)...2:
            return "Human Δ is near zero: your self-reports and predictions agree—aim for predictable breaks on heavy days."
        case 3...7:
            return "Human Δ is positive—you tend to feel better than predicted; still anchor one real off-screen break so load doesn’t spike later."
        default:
            return "Human Δ is strongly positive: you rebound well—use that as margin, not an excuse to skip wind-down before bed."
        }
    }
}
