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

            HealthInputsView()
                .tabItem {
                    Label("Health", systemImage: "heart.text.square")
                }

            ScheduleInputView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
        }
        .tint(AppTheme.accent)
        .toolbarBackground(AppTheme.tabBarBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fontDesign(.rounded)
    }
}
