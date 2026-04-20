import SwiftUI

struct CaffeineLogView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var time = ""
    @State private var mg = ""
    @State private var label = ""
    @State private var errorMessage = ""
    @State private var toastMessage: String?

    private var canAddEntry: Bool {
        InputValidator.isValidTime(time) && InputValidator.isValidCaffeine(mg)
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
                        TextField("", text: $time, prompt: caffeineTextFieldPrompt("Time (HH:mm)"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("", text: $mg, prompt: caffeineTextFieldPrompt("Caffeine mg"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .keyboardType(.numberPad)
                        TextField("", text: $label, prompt: caffeineTextFieldPrompt("Label"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.subheadline.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button("Add Entry") {
                            guard canAddEntry, let mgValue = Int(mg) else {
                                errorMessage = "Enter valid time (HH:mm) and caffeine (1-500mg)."
                                toastMessage = "Could not save. Enter valid time and caffeine."
                                return
                            }
                            store.caffeineEntries.append(
                                CaffeineEntry(time: time, mg: mgValue, label: label.isEmpty ? "Drink" : label)
                            )
                            store.saveCaffeine()
                            time = ""
                            mg = ""
                            label = ""
                            errorMessage = ""
                            toastMessage = "Caffeine entry saved."
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(!canAddEntry)
                    }
                    header: {
                        caffeineSectionHeader(title: "Add Drink", icon: "cup.and.saucer.fill")
                    }
                    .listRowBackground(AppTheme.formRowBackground)

                    Section {
                        ForEach(store.caffeineEntries) { entry in
                            HStack(alignment: .center, spacing: 12) {
                                Text(entry.time)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                Spacer(minLength: 8)
                                Text("\(entry.mg) mg")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                Text(entry.label)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteEntries)
                    } header: {
                        caffeineSectionHeader(title: "Today", icon: "clock.fill")
                    }
                    .listRowBackground(AppTheme.formRowBackground)
                }
                .fontDesign(.rounded)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Caffeine Log")
            .animation(.easeInOut(duration: 0.7), value: oceanState)
            .toastMessage($toastMessage)
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        store.caffeineEntries.remove(atOffsets: offsets)
        store.saveCaffeine()
        toastMessage = "Caffeine entry deleted."
    }

    private func caffeineSectionHeader(title: String, icon: String) -> some View {
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

    private func caffeineTextFieldPrompt(_ string: String) -> Text {
        Text(string)
            .foregroundStyle(.white.opacity(0.92))
            .font(.body.weight(.medium))
    }
}
