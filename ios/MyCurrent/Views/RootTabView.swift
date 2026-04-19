import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "waveform.path.ecg")
                }

            SleepInputView()
                .tabItem {
                    Label("Sleep", systemImage: "moon.stars")
                }

            CaffeineLogView()
                .tabItem {
                    Label("Caffeine", systemImage: "cup.and.saucer")
                }

            ScheduleInputView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
        }
        .tint(.cyan)
    }
}
