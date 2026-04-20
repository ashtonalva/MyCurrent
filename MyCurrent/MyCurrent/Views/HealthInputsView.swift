import SwiftUI

struct HealthInputsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LocalStore
    @State private var age = ""
    @State private var screenTime = ""
    @State private var activity = ""
    @State private var errorMessage = ""
    @State private var toastMessage: String?

    private var isValid: Bool {
        guard let ageValue = Int(age),
              let screenValue = Int(screenTime),
              let activityValue = Int(activity) else {
            return false
        }
        return (16...80).contains(ageValue) &&
            (0...900).contains(screenValue) &&
            (0...300).contains(activityValue)
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
                        TextField("Age", text: $age)
                            .keyboardType(.numberPad)
                        TextField("Screen Time (minutes)", text: $screenTime)
                            .keyboardType(.numberPad)
                        TextField("Activity (minutes)", text: $activity)
                            .keyboardType(.numberPad)

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    } header: {
                        Label("Daily Health Inputs", systemImage: "heart.fill")
                            .foregroundStyle(AppTheme.sectionHeader)
                    }
                    .listRowBackground(AppTheme.formRowBackground)

                    Section {
                        Button("Save Health Inputs") {
                            guard isValid,
                                  let ageValue = Int(age),
                                  let screenValue = Int(screenTime),
                                  let activityValue = Int(activity) else {
                                errorMessage = "Use realistic ranges: age 16-80, screen 0-900, activity 0-300."
                                toastMessage = "Could not save. Check input ranges."
                                return
                            }

                            store.healthProfile = HealthProfile(
                                age: ageValue,
                                screenTimeMinutes: screenValue,
                                activityMinutes: activityValue
                            )
                            store.saveHealthProfile()
                            errorMessage = ""
                            toastMessage = "Health inputs saved."
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(!isValid)
                    }
                    .listRowBackground(Color.clear)
                }
                .fontDesign(.rounded)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Health Inputs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                age = "\(store.healthProfile.age)"
                screenTime = "\(store.healthProfile.screenTimeMinutes)"
                activity = "\(store.healthProfile.activityMinutes)"
            }
            .animation(.easeInOut(duration: 0.7), value: oceanState)
            .toastMessage($toastMessage)
        }
    }
}
