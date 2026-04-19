import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: LocalStore

    private var state: DashboardState {
        DashboardCalculator.buildState(
            sleep: store.sleepLog,
            caffeine: store.caffeineEntries,
            schedule: store.scheduleBlocks
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dashboardCard(title: "Current Energy", value: "\(state.currentEnergy)/100")
                    dashboardCard(title: "Peak Window", value: state.peakWindow)
                    dashboardCard(title: "Sleep Score", value: "\(state.sleepScore)")
                    dashboardCard(title: "Caffeine Status", value: state.caffeineStatus)

                    if let crash = state.crashWindow {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Crash Warning")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            Text("\(crash.start) - \(crash.end)")
                                .font(.title3.bold())
                            Text(crash.reason)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommendations")
                            .font(.headline)
                        ForEach(state.recommendations, id: \.self) { item in
                            Text("• \(item)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
            .background(Color(red: 6/255, green: 20/255, blue: 38/255).ignoresSafeArea())
            .navigationTitle("MyCurrent")
        }
    }

    private func dashboardCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
