import SwiftUI

struct ScheduleInputView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var day = "Mon"
    @State private var start = ""
    @State private var end = ""
    @State private var label = ""
    @State private var errorMessage = ""
    @State private var toastMessage: String?
    @State private var cloudRestHints: [String] = []

    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private var canSaveBlock: Bool {
        guard let startMinutes = InputValidator.minutes(from: start),
              let endMinutes = InputValidator.minutes(from: end) else {
            return false
        }
        return startMinutes < endMinutes
    }
    
    private var oceanState: String {
        DashboardCalculator.buildState(
            sleep: store.sleepLog,
            caffeine: store.caffeineEntries,
            schedule: store.scheduleBlocks,
            profile: store.healthProfile,
            feedbackHistory: store.feedbackHistory
        ).oceanState
    }

    /// Human Delta = same personalization as Dashboard (recent self-report vs predicted); drives rest wording.
    private var localRestHints: [String] {
        HumanDeltaScheduleAdvisor.localRestRecommendations(
            schedule: store.scheduleBlocks,
            sleep: store.sleepLog,
            caffeine: store.caffeineEntries,
            profile: store.healthProfile,
            feedbackHistory: store.feedbackHistory,
            mlPredictedScore: nil
        )
    }

    /// Changes when schedule, sleep, or feedback updates — refresh cloud hints.
    private var hintsRefreshToken: String {
        "\(store.scheduleBlocks.count)-\(store.feedbackHistory.count)-\(store.sleepLog.bedtime)-\(store.sleepLog.wakeTime)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanBackground(for: oceanState)
                    .ignoresSafeArea()
                OceanVisualsView(oceanState: oceanState)
                    .ignoresSafeArea()

                Form {
                    if !cloudRestHints.isEmpty {
                        Section {
                            ForEach(Array(cloudRestHints.enumerated()), id: \.offset) { _, line in
                                scheduleHintRow(line: line, icon: "cloud.fill")
                            }
                        } header: {
                            scheduleSectionHeader(title: "Human Δ (cloud API)", icon: "cloud.fill")
                        }
                    }

                    Section {
                        ForEach(Array(localRestHints.enumerated()), id: \.offset) { _, line in
                            scheduleHintRow(line: line, icon: "leaf.circle.fill")
                        }
                    } header: {
                        scheduleSectionHeader(
                            title: cloudRestHints.isEmpty ? "Rest times (Human Δ)" : "On-device analysis",
                            icon: "figure.yoga"
                        )
                    }

                    Section {
                        Picker(selection: $day) {
                            ForEach(days, id: \.self) { day in
                                Text(day).tag(day)
                            }
                        } label: {
                            Text("Day")
                                .foregroundStyle(.white.opacity(0.95))
                                .font(.body.weight(.semibold))
                        }
                        .font(.body)
                        .foregroundStyle(.white)
                        .tint(.white)

                        TextField("", text: $start, prompt: scheduleTextFieldPrompt("Start (HH:mm)"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("", text: $end, prompt: scheduleTextFieldPrompt("End (HH:mm)"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("", text: $label, prompt: scheduleTextFieldPrompt("Label"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.subheadline.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button("Save Block") {
                            guard canSaveBlock else {
                                errorMessage = "Use HH:mm format and make sure end time is after start."
                                toastMessage = "Could not save. Fix time range and format."
                                return
                            }
                            store.scheduleBlocks.append(
                                ScheduleBlock(day: day, start: start, end: end, label: label.isEmpty ? "Class" : label)
                            )
                            store.saveSchedule()
                            start = ""
                            end = ""
                            label = ""
                            errorMessage = ""
                            toastMessage = "Schedule block saved."
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(!canSaveBlock)
                    }
                    header: {
                        scheduleSectionHeader(title: "Add block", icon: "calendar.badge.plus")
                    }
                    .listRowBackground(AppTheme.formRowBackground)

                    Section {
                        ForEach(store.scheduleBlocks) { block in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(block.day) · \(block.start) – \(block.end)")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(block.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary.opacity(0.78))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteBlocks)
                    } header: {
                        scheduleSectionHeader(title: "Your schedule", icon: "calendar")
                    }
                    .listRowBackground(AppTheme.formRowBackground)
                }
                .fontDesign(.rounded)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Schedule")
            .animation(.easeInOut(duration: 0.7), value: oceanState)
            .toastMessage($toastMessage)
            .task(id: hintsRefreshToken) {
                await refreshCloudRestHints()
            }
        }
    }

    private func scheduleSectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 1)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: 1)
                .textCase(nil)
        }
        .padding(.vertical, 2)
    }

    private func scheduleTextFieldPrompt(_ string: String) -> Text {
        Text(string)
            .foregroundStyle(.white.opacity(0.92))
            .font(.body.weight(.medium))
    }

    private func scheduleHintRow(line: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 1)
                .frame(width: 28, alignment: .center)
            Text(line)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.96))
                .lineSpacing(5)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .listRowBackground(AppTheme.formRowBackground)
    }

    private func refreshCloudRestHints() async {
        cloudRestHints = []
        guard HumanDeltaSecrets.isConfiguredForRemote else { return }
        let payload = HumanDeltaAPIService.RestPayload.build(
            schedule: store.scheduleBlocks,
            sleep: store.sleepLog,
            caffeine: store.caffeineEntries,
            profile: store.healthProfile,
            feedbackHistory: store.feedbackHistory,
            mlPredictedScore: nil
        )
        do {
            let lines = try await HumanDeltaAPIService.fetchRestHints(payload: payload)
            await MainActor.run {
                cloudRestHints = lines
            }
        } catch {
            await MainActor.run {
                cloudRestHints = []
            }
        }
    }

    private func deleteBlocks(at offsets: IndexSet) {
        store.scheduleBlocks.remove(atOffsets: offsets)
        store.saveSchedule()
        toastMessage = "Schedule block deleted."
    }
}
