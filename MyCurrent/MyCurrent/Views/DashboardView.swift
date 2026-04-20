import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var selfReportedScore: Double = 75
    @State private var toastMessage: String?
    @State private var showWhatIfSimulator = false
    @State private var showHealthActivitySheet = false
    @State private var mlPredictedScore: Int?
    @State private var mlPredictionGeneratedAt: Date?
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
                        VStack(spacing: 10) {
                            Button {
                                showWhatIfSimulator = true
                            } label: {
                                Label("Open What-If Simulator", systemImage: "slider.horizontal.3")
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)

                            Button {
                                showHealthActivitySheet = true
                            } label: {
                                Label("Report activity & health", systemImage: "heart.text.square.fill")
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.accent)
                        }

                        EnergyTimelineChartView(
                            points: state.energyPoints,
                            caffeineMarkers: state.caffeineMarkers,
                            overlayLegendUsesLightColors: true
                        )

                        LazyVGrid(columns: columns, spacing: 12) {
                            metricTile(title: "Current Energy", value: "\(state.currentEnergy)/100", icon: "bolt.fill")
                            predictedPersonalizedTile(
                                predicted: state.predictedHealthScore,
                                personalized: state.personalizedHealthScore
                            )
                            metricTile(title: "Ocean State", value: state.oceanState, icon: "water.waves")
                            metricTile(title: "Peak Window", value: state.peakWindow, icon: "sun.max.fill")
                            metricTile(title: "Sleep Score", value: "\(state.sleepScore)", icon: "moon.stars.fill")
                            metricTile(title: "Caffeine", value: state.caffeineStatus, icon: "cup.and.saucer.fill")
                        }

                        if let crash = state.crashWindow {
                            crashWarningTile(crash: crash)
                        }

                        recommendationsTile(items: state.recommendations)

                        if !store.feedbackHistory.isEmpty {
                            feedbackHistorySection
                        }

                        feedbackCard(predictedHealthScore: state.predictedHealthScore)
                    }
                    .padding()
                    .foregroundStyle(.white)
                }
                .fontDesign(.rounded)
                .tint(AppTheme.accent)
            }
            .navigationTitle("MyCurrent")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .animation(.easeInOut(duration: 0.8), value: state.oceanState)
            .onAppear {
                if let last = store.feedbackHistory.last {
                    selfReportedScore = Double(last.userReportedScore)
                } else {
                    selfReportedScore = Double(state.personalizedHealthScore)
                }
                importMLOutput(notifyOnUpdate: false, silentIfMissing: true)
                store.refreshMetricSnapshot()
            }
            .onReceive(mlAutoRefreshTimer) { _ in
                importMLOutput(notifyOnUpdate: false, silentIfMissing: true)
            }
            .sheet(isPresented: $showWhatIfSimulator) {
                WhatIfSimulatorView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showHealthActivitySheet) {
                HealthInputsView()
                    .environmentObject(store)
            }
            .toastMessage($toastMessage)
        }
    }

    private func feedbackCard(predictedHealthScore: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Personalization Feedback")
                .font(.headline)
                .foregroundStyle(.white)
            Text("How did you actually feel today?")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 8) {
                Text("Reported: \(Int(selfReportedScore))")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                DashboardFeedbackSlider(value: $selfReportedScore)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .accessibilityLabel("Self-reported feeling score")
                    .accessibilityValue("\(Int(selfReportedScore))")
            }
            .padding(.vertical, 3)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent check-ins")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Last few self-reports vs the predicted score that day. Remove any mistake so your delta bias stays accurate.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.88))
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
                    .foregroundStyle(.white.opacity(0.85))
                Text("Predicted \(entry.predictedScore) · You \(entry.userReportedScore)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text("Δ \(String(format: "%+d", delta))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(delta > 0 ? Color.green : (delta < 0 ? Color.orange : Color.white.opacity(0.85)))
            }
            Spacer(minLength: 8)
            Button(role: .destructive) {
                store.removeFeedback(id: entry.id)
                toastMessage = "Removed check-in."
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove check-in")
        }
        .padding(.vertical, 2)
    }

    private func crashWarningTile(crash: CrashWindow) -> some View {
        let accent = Color(red: 1.0, green: 0.58, blue: 0.18)
        let accentDeep = Color(red: 0.85, green: 0.35, blue: 0.08)

        return HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.95), accentDeep.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: accent.opacity(0.45), radius: 6, x: 0, y: 2)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("Energy crash risk")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .tracking(0.8)
                    .textCase(.uppercase)

                Text("Watch this window")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Text("\(crash.start) – \(crash.end)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
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
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
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

        return HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.95), accentDeep.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: accent.opacity(0.38), radius: 6, x: 0, y: 2)
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Smoother sailing")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .tracking(0.8)
                    .textCase(.uppercase)

                Text("Recommendations")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("Small shifts based on your sleep, caffeine, and daily rhythm.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items.indices, id: \.self) { index in
                        recommendationRow(text: items[index], accent: accent)
                        if index < items.count - 1 {
                            Divider()
                                .opacity(0.28)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 5)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var oceanHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "water.waves")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                Text("Ocean Ecosystem")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(state.oceanState)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.oceanStateColor(state.oceanState).opacity(0.2))
                    .clipShape(Capsule())
            }
            Text("Your habits drive the tides. Keep the ecosystem calm.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .oceanCard()
    }

    private func metricTile(title: String, value: String, icon: String) -> some View {
        GeometryReader { geo in
            let valueSize = max(18, min(31, geo.size.width * 0.175))
            let labelSize = max(11, min(13, geo.size.width * 0.075))
            let iconSize = max(14, min(18, geo.size.width * 0.10))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                }
                Text(value)
                    .font(.system(size: valueSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 98, alignment: .leading)
        .oceanCard()
    }

    private func predictedPersonalizedTile(predicted: Int, personalized: Int) -> some View {
        GeometryReader { geo in
            let valueSize = max(16, min(26, geo.size.width * 0.14))
            let labelSize = max(11, min(13, geo.size.width * 0.075))
            let iconSize = max(14, min(18, geo.size.width * 0.10))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text("Predicted & personalized")
                        .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Predicted")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("\(predicted)")
                            .font(.system(size: valueSize, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Personalized")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("\(personalized)")
                            .font(.system(size: valueSize, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 112, alignment: .leading)
        .oceanCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Predicted score \(predicted), personalized score \(personalized)")
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

// MARK: - UISlider (reliable inside ScrollView)

private struct DashboardFeedbackSlider: UIViewRepresentable {
    @Binding var value: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(binding: $value)
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.minimumTrackTintColor = UIColor(red: 0.22, green: 0.79, blue: 0.95, alpha: 1)
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.28)
        slider.thumbTintColor = .white
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return slider
    }

    func updateUIView(_ uiView: UISlider, context: Context) {
        context.coordinator.binding = $value
        let target = Float(value)
        guard !uiView.isTracking else { return }
        if abs(uiView.value - target) > 0.45 {
            uiView.value = target
        }
    }

    final class Coordinator: NSObject {
        var binding: Binding<Double>

        init(binding: Binding<Double>) {
            self.binding = binding
        }

        @objc func valueChanged(_ sender: UISlider) {
            let stepped = Double(Int(round(Double(sender.value))))
            binding.wrappedValue = stepped
        }
    }
}
