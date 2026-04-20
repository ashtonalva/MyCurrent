import SwiftUI
import Charts

struct EnergyTimelineChartView: View {
    let points: [EnergyPoint]
    let caffeineMarkers: [CaffeineMarker]
    /// Light overlay labels for dark / ocean backgrounds (e.g. Scenario Lab).
    var overlayLegendUsesLightColors: Bool = false

    private var overlayCaptionColor: Color {
        overlayLegendUsesLightColors ? Color.white.opacity(0.88) : Color.secondary
    }

    private var overlayTitleColor: Color {
        overlayLegendUsesLightColors ? Color.white.opacity(0.95) : AppTheme.sectionHeader
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Minute", point.minuteOfDay),
                        y: .value("Energy", point.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.35), Color.blue.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Minute", point.minuteOfDay),
                        y: .value("Energy", point.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.2))
                    .foregroundStyle(Color.cyan)
                }

                ForEach(caffeineMarkers) { marker in
                    RuleMark(x: .value("Caffeine", marker.minuteOfDay))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.orange.opacity(0.6))
                    PointMark(
                        x: .value("Caffeine", marker.minuteOfDay),
                        y: .value("Energy", 95)
                    )
                    .symbolSize(45)
                    .foregroundStyle(Color.orange)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXScale(domain: (8 * 60)...(22 * 60))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(maxWidth: .infinity, minHeight: 204, maxHeight: 204)

            Label("Energy Timeline", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(overlayTitleColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Capsule())
                .padding(6)

            VStack {
                Spacer()
                HStack {
                    HStack(spacing: 14) {
                        ForEach([8, 10, 12, 14, 16, 18, 20], id: \.self) { hour in
                            Text(shortHourLabel(hour))
                                .font(.caption2)
                                .foregroundStyle(overlayCaptionColor)
                        }
                    }
                    Spacer()
                    Text("Orange markers = caffeine events")
                        .font(.caption2)
                        .foregroundStyle(overlayCaptionColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 14) {
                        ForEach([100, 80, 60, 40, 20], id: \.self) { value in
                            Text("\(value)")
                                .font(.caption2)
                                .foregroundStyle(overlayCaptionColor)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 6)
                }
                Spacer()
            }
        }
        .oceanCard(contentPadding: 0)
    }

    private func shortLabel(_ minuteOfDay: Int) -> String {
        let hour24 = minuteOfDay / 60
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let amPm = hour24 >= 12 ? "P" : "A"
        return "\(hour12)\(amPm)"
    }
    
    private func shortHourLabel(_ hour24: Int) -> String {
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let amPm = hour24 >= 12 ? "P" : "A"
        return "\(hour12)\(amPm)"
    }
}
