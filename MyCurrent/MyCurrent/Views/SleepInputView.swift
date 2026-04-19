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
                        TextField("Bedtime (HH:mm)", text: $bedtime)
                        TextField("Wake Time (HH:mm)", text: $wakeTime)
                        HStack {
                            Text("Sleep Quality")
                            Spacer()
                            Text("\(Int(quality))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $quality, in: 0...100, step: 1)
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                    header: {
                        Label("Sleep Log", systemImage: "moon.zzz.fill")
                            .foregroundStyle(AppTheme.sectionHeader)
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
}
