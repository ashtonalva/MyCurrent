import SwiftUI

/// Visual Human Δ layer: baselines, trends, confidence — fed by rolling daily snapshots in `LocalStore`.
struct HumanDeltaInsightsView: View {
    @EnvironmentObject private var store: LocalStore

    private var oceanState: String {
        DashboardCalculator.buildState(
            sleep: store.sleepLog,
            caffeine: store.caffeineEntries,
            schedule: store.scheduleBlocks,
            profile: store.healthProfile,
            feedbackHistory: store.feedbackHistory
        ).oceanState
    }

    private var dimensions: [HumanDeltaVisualContext.MetricDimension] {
        HumanDeltaVisualContext.buildDimensions(from: store.metricHistory)
    }

    private var insights: [HumanDeltaVisualContext.InsightLine] {
        HumanDeltaVisualContext.ruleBasedInsights(dimensions: dimensions)
    }

    private var healthScore: Int {
        HumanDeltaVisualContext.estimateHealthScore(dimensions: dimensions)
    }

    private var averageConfidence: Double {
        guard !dimensions.isEmpty else { return 0 }
        return dimensions.map(\.confidence).reduce(0, +) / Double(dimensions.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanBackground(for: oceanState)
                    .ignoresSafeArea()
                OceanVisualsView(oceanState: oceanState)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        recoveryOverviewCard

                        sectionLabel("Live signals")

                        if dimensions.isEmpty {
                            emptyBaselinePanel
                        } else {
                            VStack(spacing: 12) {
                                ForEach(dimensions) { dim in
                                    signalPanel(dim)
                                }
                            }
                        }

                        sectionLabel("Insights")

                        insightsPanel
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .fontDesign(.rounded)
            }
            .navigationTitle("Human Δ")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear {
                store.refreshMetricSnapshot()
            }
        }
    }

    // MARK: - Recovery overview

    private var recoveryOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                scoreDial

                VStack(alignment: .leading, spacing: 6) {
                    Text(recoveryHeadline)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text(recoverySubtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Label(oceanState, systemImage: "water.waves")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.oceanStateColor(oceanState))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.oceanStateColor(oceanState).opacity(0.18))
                            .clipShape(Capsule(style: .continuous))

                        if !dimensions.isEmpty {
                            Label("\(Int(averageConfidence * 100))% model fit", systemImage: "chart.bar.doc.horizontal")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule(style: .continuous))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            dualToneDivider

            HStack {
                metricTeaser(icon: "moon.zzz.fill", title: "Sleep", active: dimensions.contains { $0.id == "sleep" })
                Spacer()
                metricTeaser(icon: "bolt.heart.fill", title: "Load", active: dimensions.contains { $0.id == "stress" })
                Spacer()
                metricTeaser(icon: "figure.run", title: "Move", active: dimensions.contains { $0.id == "activity" })
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    AppTheme.accent.opacity(0.35),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 10)
        )
    }

    private var scoreDial: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 9)
                .frame(width: 92, height: 92)

            Circle()
                .trim(from: 0, to: CGFloat(healthScore) / 100)
                .stroke(
                    AngularGradient(
                        colors: [
                            AppTheme.accent.opacity(0.85),
                            Color.teal,
                            Color.mint.opacity(0.9),
                            AppTheme.accent
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(healthScore)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("/100")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recovery score \(healthScore) out of 100")
    }

    private var recoveryHeadline: String {
        if dimensions.isEmpty { return "Baseline forming" }
        switch healthScore {
        case ..<45: return "Needs attention"
        case ..<65: return "Room to recover"
        case ..<82: return "Steady rhythm"
        default: return "Strong balance"
        }
    }

    private var recoverySubtitle: String {
        if dimensions.isEmpty {
            return "Log sleep and check the dashboard for a few days — your Δ view unlocks after snapshots arrive."
        }
        return "Score blends sleep, stress load, and movement vs your rolling averages."
    }

    private func metricTeaser(icon: String, title: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(active ? AppTheme.accent : Color.white.opacity(0.35))
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(active ? Color.white : Color.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    private var dualToneDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0), Color.white.opacity(0.22), Color.white.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }

    // MARK: - Section chrome

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(AppTheme.sectionHeader)
            .textCase(.uppercase)
            .tracking(1.1)
            .padding(.leading, 2)
    }

    // MARK: - Empty state

    private var emptyBaselinePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("No streak yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("We keep the last 14 daily snapshots on-device. Save sleep or visit Dashboard to seed your chart.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Signal panels

    private func signalPanel(_ dim: HumanDeltaVisualContext.MetricDimension) -> some View {
        let palette = metricPalette(for: dim.id)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.accent.opacity(0.55), palette.accent.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                        )

                    Image(systemName: palette.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(dim.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        trendGlyph(dim.trend)
                    }

                    if let dev = dim.deviation {
                        Text(deviationLabel(dim: dim, deviation: dev))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(deviationColor(dim: dim, deviation: dev))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatValue(dim.value, unit: dim.unit))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.8)
                    if let b = dim.baseline {
                        Text("avg \(formatValue(b, unit: dim.unit))")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }

            wellnessPositionBar(normalized: dim.normalizedValuePosition, tint: palette.accent)

            baselineValueTrack(dim: dim)

            HStack(spacing: 10) {
                Text("Confidence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent.opacity(0.35), palette.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * CGFloat(dim.confidence)))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 7)

                Text("\(Int(dim.confidence * 100))%")
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 38, alignment: .trailing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    palette.accent.opacity(0.35),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
        )
    }

    private func wellnessPositionBar(normalized: Double, tint: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let knobX = CGFloat(normalized) * w
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.15),
                                Color.white.opacity(0.14),
                                tint.opacity(0.22)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 8)

                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .offset(x: max(0, min(knobX - 7, w - 14)))
            }
        }
        .frame(height: 14)
        .accessibilityLabel("Wellness band position")
        .accessibilityValue("\(Int(normalized * 100)) percent along range")
    }

    private func metricPalette(for id: String) -> (accent: Color, icon: String) {
        switch id {
        case "sleep":
            return (Color(red: 0.42, green: 0.36, blue: 0.92), "moon.zzz.fill")
        case "stress":
            return (Color(red: 0.98, green: 0.52, blue: 0.35), "bolt.heart.fill")
        case "activity":
            return (Color(red: 0.28, green: 0.82, blue: 0.62), "figure.run")
        default:
            return (AppTheme.accent, "gauge.medium")
        }
    }

    @ViewBuilder
    private func trendGlyph(_ trend: HumanDeltaVisualContext.TrendLabel) -> some View {
        switch trend {
        case .increasing:
            Label("Rising", systemImage: "arrow.up.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.orange.opacity(0.95))
        case .decreasing:
            Label("Falling", systemImage: "arrow.down.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.cyan.opacity(0.95))
        case .stable:
            Label("Flat", systemImage: "equal")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
        case .insufficientData:
            Label("Early", systemImage: "ellipsis")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }

    // MARK: - Insights

    private var insightsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if insights.isEmpty {
                Text("Quiet for now — deviations or trends will surface here when they clear the threshold.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, line in
                    insightRow(line: line)
                    if index < insights.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                            .padding(.leading, 42)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        )
    }

    private func insightRow(line: HumanDeltaVisualContext.InsightLine) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkle")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 26, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(line.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(metaLine(for: line))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func metaLine(for line: HumanDeltaVisualContext.InsightLine) -> String {
        let readableCause = line.cause
            .replacingOccurrences(of: ".", with: " · ")
            .replacingOccurrences(of: "_", with: " ")
        return "\(Int(line.confidence * 100))% confidence · \(readableCause)"
    }

    // MARK: - Formatting & baseline track

    private func deviationLabel(dim: HumanDeltaVisualContext.MetricDimension, deviation: Double) -> String {
        let sign = deviation >= 0 ? "+" : ""
        switch dim.id {
        case "sleep":
            return "\(sign)\(String(format: "%.2f", deviation)) h vs baseline"
        case "stress":
            return "\(sign)\(String(format: "%.2f", deviation)) vs baseline on 0–10 scale"
        case "activity":
            return "\(sign)\(String(format: "%.0f", deviation)) min vs baseline"
        default:
            return "\(sign)\(String(format: "%.2f", deviation)) vs baseline"
        }
    }

    private func deviationColor(dim: HumanDeltaVisualContext.MetricDimension, deviation: Double) -> Color {
        switch dim.id {
        case "stress":
            return deviation > 0.6 ? .orange : .mint
        case "sleep", "activity":
            return deviation < -0.4 ? .orange : .mint
        default:
            return .white.opacity(0.9)
        }
    }

    private func formatValue(_ v: Double, unit: String) -> String {
        if unit == "min" {
            return "\(Int(v.rounded()))\(unit)"
        }
        return String(format: "%.1f%@", v, unit)
    }

    @ViewBuilder
    private func baselineValueTrack(dim: HumanDeltaVisualContext.MetricDimension) -> some View {
        let value = dim.value
        if let baseline = dim.baseline {
            let span = max(abs(value - baseline), abs(value), abs(baseline), 1) * 1.35
            let mid = (value + baseline) / 2
            let low = mid - span / 2
            let range = max(span, 0.01)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 5)

                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 6, height: 6)
                        .offset(x: CGFloat((baseline - low) / range) * w - 3)

                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 8, height: 8)
                        .offset(x: CGFloat((value - low) / range) * w - 4)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack {
                        Text("Low")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.82))
                        Spacer()
                        Text("High")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .offset(y: 11)
                }
            }
            .frame(height: 22)
        } else {
            Color.clear.frame(height: 2)
        }
    }
}

#Preview {
    HumanDeltaInsightsView()
        .environmentObject(LocalStore())
}
