import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var selfReportedScore: Double = 75
    @State private var toastMessage: String?
    @State private var showWhatIfSimulator = false
    @State private var mlPredictedScore: Int?
    @State private var mlPredictionGeneratedAt: Date?
    @State private var showDeltaBiasInfo = false
    private let mlBridgeService = MLBridgeService()
    private let mlAutoRefreshTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var state: DashboardState {
        DashboardCalculator.buildState(
            sleep: store.sleepLog,
            caffeine: store.caffeineEntries,
            schedule: store.scheduleBlocks,
            profile: store.healthProfile,
            feedbackHistory: store.feedbackHistory,
            mlPredictedScore: activeMLPredictedScore
        )
    }
    
    private var activeMLPredictedScore: Int? {
        guard let score = mlPredictedScore else { return nil }
        guard let exportedAt = store.lastMLInputExportAt else { return score }
        guard let generatedAt = mlPredictionGeneratedAt else { return nil }
        return generatedAt >= exportedAt ? score : nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanBackground(for: state.oceanState)
                    .ignoresSafeArea()
                OceanVisualsView(oceanState: state.oceanState)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        oceanHeader
                        Button {
                            showWhatIfSimulator = true
                        } label: {
                            Label("Open What-If Simulator", systemImage: "slider.horizontal.3")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)

                        EnergyTimelineChartView(
                            points: state.energyPoints,
                            caffeineMarkers: state.caffeineMarkers
                        )

                        LazyVGrid(columns: columns, spacing: 12) {
                            metricTile(title: "Current Energy", value: "\(state.currentEnergy)/100", icon: "bolt.fill")
                            metricTile(title: "Predicted", value: "\(state.predictedHealthScore)", icon: "chart.bar.fill")
                            metricTile(title: "ML Score", value: activeMLPredictedScore.map(String.init) ?? "Stale", icon: "brain")
                            metricTile(title: "Personalized", value: "\(state.personalizedHealthScore)", icon: "person.crop.circle.fill")
                            metricTile(title: "Ocean State", value: state.oceanState, icon: "water.waves")
                            metricTile(title: "Peak Window", value: state.peakWindow, icon: "sun.max.fill")
                            metricTile(title: "Sleep Score", value: "\(state.sleepScore)", icon: "moon.stars.fill")
                            metricTile(title: "Caffeine", value: state.caffeineStatus, icon: "cup.and.saucer.fill")
                            deltaBiasTile(bias: state.userDeltaBias)
                        }

                        if let crash = state.crashWindow {
                            crashWarningTile(crash: crash)
                        }

                        recommendationsTile(items: state.recommendations)

                        feedbackCard(predictedHealthScore: state.predictedHealthScore)

                        if !store.feedbackHistory.isEmpty {
                            feedbackHistorySection
                        }
                    }
                    .padding()
                }
                .fontDesign(.rounded)
            }
            .navigationTitle("MyCurrent")
            .animation(.easeInOut(duration: 0.8), value: state.oceanState)
            .onAppear {
                if let last = store.feedbackHistory.last {
                    selfReportedScore = Double(last.userReportedScore)
                } else {
                    selfReportedScore = Double(state.personalizedHealthScore)
                }
                importMLOutput(notifyOnUpdate: false, silentIfMissing: true)
            }
            .onReceive(mlAutoRefreshTimer) { _ in
                importMLOutput(notifyOnUpdate: false, silentIfMissing: true)
            }
            .sheet(isPresented: $showWhatIfSimulator) {
                WhatIfSimulatorView()
                    .environmentObject(store)
            }
            .toastMessage($toastMessage)
            .alert("Delta Bias", isPresented: $showDeltaBiasInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    "This is your personalization offset. We compare your self-reported score to the predicted score on recent days, average the difference, and add it to your personalized score (capped between −15 and +15). Positive means you usually feel better than the model expects; negative means lower."
                )
            }
        }
    }

    private func feedbackCard(predictedHealthScore: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personalization Feedback")
                .font(.headline)
            Text("How did you actually feel today?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text("Reported: \(Int(selfReportedScore))")
                Slider(value: $selfReportedScore, in: 0...100, step: 1)
                    .controlSize(.large)
            }
            .padding(.vertical, 6)
            Button("Save Feedback") {
                store.submitFeedback(
                    predictedScore: predictedHealthScore,
                    userReportedScore: Int(selfReportedScore)
                )
                toastMessage = "Feedback saved. Personalization updated."
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .oceanCard()
    }

    private var feedbackHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent check-ins")
                .font(.headline)
            Text("Last few self-reports vs the predicted score that day. Remove any mistake so your delta bias stays accurate.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(store.feedbackHistory.reversed().prefix(10).enumerated()), id: \.element.id) { index, entry in
                feedbackHistoryRow(entry: entry)
                if index < min(10, store.feedbackHistory.count) - 1 {
                    Divider().opacity(0.35)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .oceanCard()
    }

    private func feedbackHistoryRow(entry: UserScoreFeedback) -> some View {
        let delta = entry.userReportedScore - entry.predictedScore
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Predicted \(entry.predictedScore) · You \(entry.userReportedScore)")
                    .font(.subheadline.weight(.medium))
                Text("Δ \(String(format: "%+d", delta))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(delta > 0 ? Color.green : (delta < 0 ? Color.orange : Color.secondary))
            }
            Spacer(minLength: 8)
            Button(role: .destructive) {
                store.removeFeedback(id: entry.id)
                toastMessage = "Removed check-in."
            } label: {
                Image(systemName: "trash")
                    .font(.body)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove check-in")
        }
        .padding(.vertical, 4)
    }

    private func crashWarningTile(crash: CrashWindow) -> some View {
        let accent = Color(red: 1.0, green: 0.58, blue: 0.18)
        let accentDeep = Color(red: 0.85, green: 0.35, blue: 0.08)

        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.95), accentDeep.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: accent.opacity(0.45), radius: 8, x: 0, y: 3)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Energy crash risk")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .tracking(0.8)
                    .textCase(.uppercase)

                Text("Watch this window")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Text("\(crash.start) – \(crash.end)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(accent.opacity(0.14))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
                )

                Text(crash.reason)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.14),
                                Color.red.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.55), accent.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: accent.opacity(0.2), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Energy crash risk from \(crash.start) to \(crash.end). \(crash.reason)")
    }

    private func recommendationsTile(items: [String]) -> some View {
        let accent = AppTheme.accent
        let accentDeep = Color(red: 0.06, green: 0.48, blue: 0.72)

        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.95), accentDeep.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: accent.opacity(0.38), radius: 8, x: 0, y: 3)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                Text("Smoother sailing")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .tracking(0.8)
                    .textCase(.uppercase)

                Text("Recommendations")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                Text("Small shifts based on your sleep, caffeine, and daily rhythm.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items.indices, id: \.self) { index in
                        recommendationRow(text: items[index], accent: accent)
                        if index < items.count - 1 {
                            Divider()
                                .opacity(0.28)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.12),
                                Color.blue.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.5), accent.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: accent.opacity(0.18), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Recommendations. " + items.joined(separator: " ")
        )
    }

    private func recommendationRow(text: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 6)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var oceanHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "water.waves")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                Text("Ocean Ecosystem")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Text(state.oceanState)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.oceanStateColor(state.oceanState).opacity(0.2))
                    .clipShape(Capsule())
            }
            Text("Your habits drive the tides. Keep the ecosystem calm.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .oceanCard()
    }

    private func metricTile(title: String, value: String, icon: String) -> some View {
        GeometryReader { geo in
            let valueSize = max(18, min(30, geo.size.width * 0.16))
            let labelSize = max(11, min(13, geo.size.width * 0.075))
            let iconSize = max(14, min(18, geo.size.width * 0.10))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(value)
                    .font(.system(size: valueSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 130, alignment: .leading)
        .oceanCard()
    }

    private func deltaBiasTile(bias: Int) -> some View {
        GeometryReader { geo in
            let valueSize = max(18, min(30, geo.size.width * 0.16))
            let labelSize = max(11, min(13, geo.size.width * 0.075))
            let iconSize = max(14, min(18, geo.size.width * 0.10))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "dial.medium.fill")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text("Delta Bias")
                        .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button {
                        showDeltaBiasInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("What is Delta Bias?")
                }
                Spacer(minLength: 0)
                Text("\(bias >= 0 ? "+" : "")\(bias)")
                    .font(.system(size: valueSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 130, alignment: .leading)
        .oceanCard()
    }
    
    private func importMLOutput(notifyOnUpdate: Bool = true, silentIfMissing: Bool = false) {
        do {
            let prediction = try mlBridgeService.loadPrediction()
            let score = prediction?.score
            let hasChanged = score != nil && score != mlPredictedScore
            mlPredictedScore = score
            mlPredictionGeneratedAt = prediction?.generatedAt
            if hasChanged && notifyOnUpdate {
                toastMessage = "Loaded ML prediction into dashboard."
            } else if score == nil && !silentIfMissing {
                toastMessage = "No ML output found yet."
            } else if !silentIfMissing {
                toastMessage = "ML prediction already up to date."
            }
        } catch {
            if !silentIfMissing {
                toastMessage = "Failed to load ML output."
            }
        }
    }
}
