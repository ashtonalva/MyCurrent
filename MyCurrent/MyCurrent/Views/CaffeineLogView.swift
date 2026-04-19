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
                        TextField("Time (HH:mm)", text: $time)
                        TextField("Caffeine mg", text: $mg)
                            .keyboardType(.numberPad)
                        TextField("Label", text: $label)
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
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
                        Label("Add Drink", systemImage: "cup.and.saucer.fill")
                            .foregroundStyle(AppTheme.sectionHeader)
                    }
                    .listRowBackground(AppTheme.formRowBackground)

                    Section {
                        ForEach(store.caffeineEntries) { entry in
                            HStack {
                                Text(entry.time)
                                Spacer()
                                Text("\(entry.mg)mg")
                                Text(entry.label)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    } header: {
                        Label("Today", systemImage: "clock.fill")
                            .foregroundStyle(AppTheme.sectionHeader)
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
}
