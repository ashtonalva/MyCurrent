import SwiftUI

struct CaffeineLogView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var time = ""
    @State private var mg = ""
    @State private var label = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Drink") {
                    TextField("Time (HH:mm)", text: $time)
                    TextField("Caffeine mg", text: $mg)
                        .keyboardType(.numberPad)
                    TextField("Label", text: $label)

                    Button("Add Entry") {
                        guard let mgValue = Int(mg), !time.isEmpty else { return }
                        store.caffeineEntries.append(
                            CaffeineEntry(time: time, mg: mgValue, label: label.isEmpty ? "Drink" : label)
                        )
                        store.saveCaffeine()
                        time = ""
                        mg = ""
                        label = ""
                    }
                }

                Section("Today") {
                    ForEach(store.caffeineEntries) { entry in
                        HStack {
                            Text(entry.time)
                            Spacer()
                            Text("\(entry.mg)mg")
                            Text(entry.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Caffeine Log")
        }
    }
}
