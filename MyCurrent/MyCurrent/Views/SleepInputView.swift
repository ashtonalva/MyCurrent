import SwiftUI

struct SleepInputView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var bedtime = ""
    @State private var wakeTime = ""
    @State private var quality: Double = 70
    @State private var errorMessage = ""
    @State private var toastMessage: String?

    private var isValidInput: Bool {
        InputValidator.isValidTime(bedtime) && InputValidator.isValidTime(wakeTime)
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

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanBackground(for: oceanState)
                    .ignoresSafeArea()
                OceanVisualsView(oceanState: oceanState)
                    .ignoresSafeArea()

                Form {
                    Section {
                        TextField("", text: $bedtime, prompt: sleepTextFieldPrompt("Bedtime (HH:mm)"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("", text: $wakeTime, prompt: sleepTextFieldPrompt("Wake Time (HH:mm)"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                        HStack {
                            Text("Sleep Quality")
                                .foregroundStyle(.white.opacity(0.95))
                                .font(.body.weight(.semibold))
                            Spacer()
                            Text("\(Int(quality))")
                                .foregroundStyle(.white)
                                .font(.body.weight(.bold).monospacedDigit())
                        }
                        Slider(value: $quality, in: 0...100, step: 1)
                            .tint(AppTheme.accent)
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.subheadline.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    header: {
                        sleepSectionHeader(title: "Sleep Log", icon: "moon.zzz.fill")
                    }
                    .listRowBackground(AppTheme.formRowBackground)

                    Section {
                        Button("Save Sleep Data") {
                            guard isValidInput else {
                                errorMessage = "Use 24-hour HH:mm format (example: 23:30)."
                                toastMessage = "Could not save. Check time format (HH:mm)."
                                return
                            }
                            store.sleepLog = SleepLog(bedtime: bedtime, wakeTime: wakeTime, quality: Int(quality))
                            store.saveSleep()
                            errorMessage = ""
                            toastMessage = "Sleep data saved."
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                    }
                    .listRowBackground(Color.clear)
                }
                .fontDesign(.rounded)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Sleep Input")
            .onAppear {
                bedtime = store.sleepLog.bedtime
                wakeTime = store.sleepLog.wakeTime
                quality = Double(store.sleepLog.quality)
            }
            .animation(.easeInOut(duration: 0.7), value: oceanState)
            .toastMessage($toastMessage)
        }
    }

    private func sleepSectionHeader(title: String, icon: String) -> some View {
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

    private func sleepTextFieldPrompt(_ string: String) -> Text {
        Text(string)
            .foregroundStyle(.white.opacity(0.92))
            .font(.body.weight(.medium))
    }
}
