import Foundation

/// Builds Human Δ–style dimensions for UI (baseline, deviation, trend, confidence) from daily snapshots.
enum HumanDeltaVisualContext {

    enum TrendLabel: String {
        case increasing
        case decreasing
        case stable
        case insufficientData
    }

    struct MetricDimension: Identifiable {
        let id: String
        let title: String
        let unit: String
        let value: Double
        let baseline: Double?
        let deviation: Double?
        let trend: TrendLabel
        let confidence: Double
        /// 0–1 where 1 means value is at the “good” end for that metric (more sleep, lower stress, moderate–high activity).
        var normalizedValuePosition: Double
    }

    struct InsightLine: Identifiable {
        let message: String
        let confidence: Double
        let cause: String
        var id: String { cause }
    }

    static func stressProxy(
        caffeineTotalMg: Int,
        scheduleBlockCount: Int,
        screenMinutes: Int
    ) -> Double {
        let c = Double(caffeineTotalMg) / 55.0
        let s = Double(scheduleBlockCount) * 0.85
        let scr = Double(screenMinutes) / 100.0
        return min(10, max(0, 2.4 + c * 0.35 + s + scr * 0.25))
    }

    static func buildDimensions(from snapshots: [DailyMetricSnapshot]) -> [MetricDimension] {
        let sorted = snapshots.sorted { $0.dayId < $1.dayId }
        guard !sorted.isEmpty else { return [] }

        let sleepSeries = sorted.map(\.sleepHours)
        let stressSeries = sorted.map(\.stressProxy)
        let activitySeries = sorted.map { Double($0.activityMinutes) }

        return [
            makeDim(
                id: "sleep",
                title: "Sleep",
                unit: "h",
                series: sleepSeries,
                goodDirection: .higher,
                displayTransform: { $0 }
            ),
            makeDim(
                id: "stress",
                title: "Stress load",
                unit: "/10",
                series: stressSeries,
                goodDirection: .lower,
                displayTransform: { $0 }
            ),
            makeDim(
                id: "activity",
                title: "Activity",
                unit: "min",
                series: activitySeries,
                goodDirection: .higher,
                displayTransform: { $0 }
            )
        ]
    }

    private enum GoodDirection {
        case higher
        case lower
    }

    private static func makeDim(
        id: String,
        title: String,
        unit: String,
        series: [Double],
        goodDirection: GoodDirection,
        displayTransform: (Double) -> Double
    ) -> MetricDimension {
        let baseline = series.isEmpty ? nil : series.reduce(0, +) / Double(series.count)
        let current = series.last
        let deviation: Double?
        if let c = current, let b = baseline {
            deviation = c - b
        } else {
            deviation = nil
        }

        let trend = segmentTrend(series: series)
        let confidence = metricConfidence(series: series, expectedDays: 14)

        let normPos: Double
        if let c = current {
            switch goodDirection {
            case .higher:
                normPos = min(1, max(0, c / (id == "sleep" ? 10 : (id == "activity" ? 180 : 10))))
            case .lower:
                normPos = min(1, max(0, 1 - c / 10))
            }
        } else {
            normPos = 0.5
        }

        return MetricDimension(
            id: id,
            title: title,
            unit: unit,
            value: displayTransform(current ?? 0),
            baseline: baseline.map { displayTransform($0) },
            deviation: deviation.map { displayTransform($0) },
            trend: trend,
            confidence: confidence,
            normalizedValuePosition: normPos
        )
    }

    private static func segmentTrend(series: [Double]) -> TrendLabel {
        guard series.count >= 6 else { return .insufficientData }
        let recent = Array(series.suffix(3))
        let prior = Array(series.dropLast(3).suffix(3))
        let r = recent.reduce(0, +) / Double(recent.count)
        let p = prior.reduce(0, +) / Double(prior.count)
        let delta = r - p
        let threshold = max(0.08 * (abs(p) + 1), 0.12)
        if delta > threshold { return .increasing }
        if delta < -threshold { return .decreasing }
        return .stable
    }

    private static func metricConfidence(series: [Double], expectedDays: Int) -> Double {
        guard !series.isEmpty else { return 0.25 }
        let n = series.count
        let completeness = min(1, Double(n) / Double(expectedDays))
        let mean = series.reduce(0, +) / Double(series.count)
        let variance: Double
        if series.count < 2 {
            variance = 0
        } else {
            variance = series.map { pow($0 - mean, 2) }.reduce(0, +) / Double(series.count - 1)
        }
        let std = sqrt(variance)
        let cv = abs(mean) > 1e-6 ? std / abs(mean) : 0
        let consistency = 1 / (1 + cv)

        let raw = 0.45 * completeness + 0.55 * consistency
        let scaled: Double
        if raw >= 0.72 {
            scaled = 0.78 + 0.22 * min(1, (raw - 0.72) / 0.28)
        } else if raw >= 0.45 {
            scaled = 0.42 + 0.36 * ((raw - 0.45) / 0.27)
        } else {
            scaled = 0.25 + 0.17 * (raw / 0.45)
        }
        return min(1, max(0, scaled))
    }

    static func ruleBasedInsights(dimensions: [MetricDimension]) -> [InsightLine] {
        var lines: [InsightLine] = []
        func dim(_ id: String) -> MetricDimension? {
            dimensions.first { $0.id == id }
        }

        if let s = dim("sleep"), let d = s.deviation, d < -0.85 {
            lines.append(InsightLine(
                message: "Sleep is running below your recent baseline.",
                confidence: s.confidence,
                cause: "sleep.deviation"
            ))
        }
        if let st = dim("stress"), let d = st.deviation, d > 1 {
            lines.append(InsightLine(
                message: "Stress signals are elevated versus your usual pattern.",
                confidence: st.confidence,
                cause: "stress.deviation"
            ))
        }
        if let a = dim("activity"), let d = a.deviation, d < -25 {
            lines.append(InsightLine(
                message: "Activity has dipped—recovery may feel flatter.",
                confidence: a.confidence,
                cause: "activity.deviation"
            ))
        }
        if let s = dim("sleep"), s.trend == .decreasing {
            lines.append(InsightLine(
                message: "Sleep hours have trended down over the last few days.",
                confidence: s.confidence * 0.95,
                cause: "sleep.trend"
            ))
        }

        var seen = Set<String>()
        return Array(lines.filter { seen.insert($0.cause).inserted }.prefix(6))
    }

    static func estimateHealthScore(dimensions: [MetricDimension]) -> Int {
        var score = 72.0
        if let s = dimensions.first(where: { $0.id == "sleep" }), let d = s.deviation {
            if d < -1.5 { score -= 14 }
            else if d < -0.75 { score -= 8 }
            else if d > 0.5 { score += 3 }
        }
        if let st = dimensions.first(where: { $0.id == "stress" }), let d = st.deviation {
            if d > 1.5 { score -= 12 }
            else if d > 0.75 { score -= 6 }
        }
        if let a = dimensions.first(where: { $0.id == "activity" }), let d = a.deviation {
            if d < -30 { score -= 8 }
            else if d > 20 { score += 2 }
        }
        let avgConf = dimensions.isEmpty
            ? 0.5
            : dimensions.map(\.confidence).reduce(0, +) / Double(dimensions.count)
        if avgConf < 0.45 {
            score -= 4
        }
        return Int(max(0, min(100, score.rounded())))
    }
}
