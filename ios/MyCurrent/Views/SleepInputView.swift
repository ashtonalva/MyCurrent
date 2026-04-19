import SwiftUI

struct SleepInputView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var bedtime = ""
    @State private var wakeTime = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Sleep Log") {
                    TextField("Bedtime (HH:mm)", text: $bedtime)
                    TextField("Wake Time (HH:mm)", text: $wakeTime)
                }

                Button("Save Sleep Data") {
                    store.sleepLog = SleepLog(bedtime: bedtime, wakeTime: wakeTime)
                    store.saveSleep()
                }
            }
            .navigationTitle("Sleep Input")
            .onAppear {
                bedtime = store.sleepLog.bedtime
                wakeTime = store.sleepLog.wakeTime
            }
        }
    }
}
