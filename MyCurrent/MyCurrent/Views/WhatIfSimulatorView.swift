import SwiftUI

struct WhatIfSimulatorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LocalStore

    @State private var sleepHours: Double = 7.5
    @State private var sleepQuality: Double = 70
    @State private var caffeineMg: Double = 160
    @State private var screenMinutes: Double = 240
    @State private var activityMinutes: Double = 45
    @State private var didInitialize = false

    private var previewState: DashboardState {
        let syntheticSleep = SleepLog(
            bedtime: bedtime(for: sleepHours),
            wakeTime: "07:30",
            quality: Int(sleepQuality)
        )
        let syntheticCaffeine: [CaffeineEntry] = caffeineMg > 0
            ? [CaffeineEntry(time: "11:00", mg: Int(caffeineMg), label: "Simulated Intake")]
            : []
        let syntheticProfile = HealthProfile(
            age: store.healthProfile.age,
            screenTimeMinutes: Int(screenMinutes),
            activityMinutes: Int(activityMinutes)
        )

        return DashboardCalculator.buildState(
            sleep: syntheticSleep,
            caffeine: syntheticCaffeine,
            schedule: store.scheduleBlocks,
            profile: syntheticProfile,
            feedbackHistory: store.feedbackHistory,
            mlPredictedScore: nil
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanBackground(for: previewState.oceanState)
                    .ignoresSafeArea()
                OceanVisualsView(oceanState: previewState.oceanState)
                    .ignoresSafeArea()

                // Form avoids ScrollView vs. Slider gesture conflict (horizontal drags).
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("What-If Simulator", systemImage: "slider.horizontal.3")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Adjust inputs to preview how your score and ocean state would change.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .listRowBackground(Color.clear)
                    }

                    simulatorSection(
                        title: "Sleep Hours",
                        value: String(format: "%.1f h", sleepHours),
                        range: 4...10,
                        step: 0.5,
                        binding: $sleepHours
                    )
                    simulatorSection(
                        title: "Sleep Quality",
                        value: "\(Int(sleepQuality))",
                        range: 0...100,
                        step: 1,
                        binding: $sleepQuality
                    )
                    simulatorSection(
                        title: "Caffeine",
                        value: "\(Int(caffeineMg)) mg",
                        range: 0...350,
                        step: 10,
                        binding: $caffeineMg
                    )
                    simulatorSection(
                        title: "Screen Time",
                        value: "\(Int(screenMinutes)) min",
                        range: 0...600,
                        step: 10,
                        binding: $screenMinutes
                    )
                    simulatorSection(
                        title: "Activity",
                        value: "\(Int(activityMinutes)) min",
                        range: 0...180,
                        step: 5,
                        binding: $activityMinutes
                    )

                    Section {
                        HStack(spacing: 10) {
                            metricPill(title: "Predicted", value: "\(previewState.predictedHealthScore)")
                            metricPill(title: "Personalized", value: "\(previewState.personalizedHealthScore)")
                            metricPill(title: "State", value: previewState.oceanState)
                        }
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        EnergyTimelineChartView(
                            points: previewState.energyPoints,
                            caffeineMarkers: previewState.caffeineMarkers,
                            overlayLegendUsesLightColors: true
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .tint(AppTheme.accent)
                .padding(.horizontal, 4)
            }
            .navigationTitle("Scenario Lab")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                guard !didInitialize else { return }
                didInitialize = true
                sleepHours = max(4, min(10, estimatedSleepHours(from: store.sleepLog)))
                sleepQuality = Double(store.sleepLog.quality)
                caffeineMg = Double(store.caffeineEntries.reduce(0) { $0 + $1.mg })
                screenMinutes = Double(store.healthProfile.screenTimeMinutes)
                activityMinutes = Double(store.healthProfile.activityMinutes)
            }
        }
    }

    private func simulatorSection(
        title: String,
        value: String,
        range: ClosedRange<Double>,
        step: Double,
        binding: Binding<Double>
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(value)
                        .foregroundStyle(.white.opacity(0.92))
                        .monospacedDigit()
                }
                Slider(value: binding, in: range, step: step)
                    .tint(AppTheme.accent)
            }
            .padding(.vertical, 4)
            .listRowBackground(AppTheme.formRowBackground)
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .oceanCard()
    }

    private func estimatedSleepHours(from sleep: SleepLog) -> Double {
        let bed = minutes(from: sleep.bedtime)
        let wake = minutes(from: sleep.wakeTime)
        let duration = wake >= bed ? wake - bed : (24 * 60 - bed) + wake
        return Double(duration) / 60.0
    }

    private func bedtime(for hours: Double) -> String {
        let wake = 7 * 60 + 30
        let sleepMinutes = Int(hours * 60.0)
        var bedtimeMinutes = wake - sleepMinutes
        if bedtimeMinutes < 0 {
            bedtimeMinutes += 24 * 60
        }
        return hhmm(from: bedtimeMinutes)
    }

    private func hhmm(from minuteOfDay: Int) -> String {
        let h = minuteOfDay / 60
        let m = minuteOfDay % 60
        return String(format: "%02d:%02d", h, m)
    }

    private func minutes(from hhmm: String) -> Int {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0 }
        return (parts[0] * 60) + parts[1]
    }
}
