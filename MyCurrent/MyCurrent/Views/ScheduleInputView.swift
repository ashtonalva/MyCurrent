import SwiftUI

struct ScheduleInputView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var day = "Mon"
    @State private var start = ""
    @State private var end = ""
    @State private var label = ""
    @State private var errorMessage = ""
    @State private var toastMessage: String?

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

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.oceanBackground(for: oceanState)
                    .ignoresSafeArea()
                OceanVisualsView(oceanState: oceanState)
                    .ignoresSafeArea()

                Form {
                    Section {
                        Picker("Day", selection: $day) {
                            ForEach(days, id: \.self) { Text($0) }
                        }
                        TextField("Start (HH:mm)", text: $start)
                        TextField("End (HH:mm)", text: $end)
                        TextField("Label", text: $label)
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
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
                        Label("Add Block", systemImage: "calendar.badge.plus")
                            .foregroundStyle(AppTheme.sectionHeader)
                    }
                    .listRowBackground(AppTheme.formRowBackground)

                    Section {
                        ForEach(store.scheduleBlocks) { block in
                            VStack(alignment: .leading) {
                                Text("\(block.day) \(block.start)-\(block.end)")
                                Text(block.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: deleteBlocks)
                    } header: {
                        Label("Schedule", systemImage: "calendar")
                            .foregroundStyle(AppTheme.sectionHeader)
                    }
                    .listRowBackground(AppTheme.formRowBackground)
                }
                .fontDesign(.rounded)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Schedule")
            .animation(.easeInOut(duration: 0.7), value: oceanState)
            .toastMessage($toastMessage)
        }
    }

    private func deleteBlocks(at offsets: IndexSet) {
        store.scheduleBlocks.remove(atOffsets: offsets)
        store.saveSchedule()
        toastMessage = "Schedule block deleted."
    }
}
