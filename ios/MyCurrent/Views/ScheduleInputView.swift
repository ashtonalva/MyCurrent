import SwiftUI

struct ScheduleInputView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var day = "Mon"
    @State private var start = ""
    @State private var end = ""
    @State private var label = ""

    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Block") {
                    Picker("Day", selection: $day) {
                        ForEach(days, id: \.self) { Text($0) }
                    }
                    TextField("Start (HH:mm)", text: $start)
                    TextField("End (HH:mm)", text: $end)
                    TextField("Label", text: $label)

                    Button("Save Block") {
                        guard !start.isEmpty, !end.isEmpty else { return }
                        store.scheduleBlocks.append(
                            ScheduleBlock(day: day, start: start, end: end, label: label.isEmpty ? "Class" : label)
                        )
                        store.saveSchedule()
                        start = ""
                        end = ""
                        label = ""
                    }
                }

                Section("Schedule") {
                    ForEach(store.scheduleBlocks) { block in
                        VStack(alignment: .leading) {
                            Text("\(block.day) \(block.start)-\(block.end)")
                            Text(block.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
        }
    }
}
