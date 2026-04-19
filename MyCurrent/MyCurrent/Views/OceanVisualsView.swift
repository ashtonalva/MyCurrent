import SwiftUI

struct OceanVisualsView: View {
    let oceanState: String

    private var weather: OceanWeatherProfile {
        OceanWeatherProfile(state: oceanState)
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    // Sun glow near ocean surface.
                    RadialGradient(
                        colors: [weather.glowColor.opacity(weather.glowOpacity), Color.clear],
                        center: .top,
                        startRadius: 30,
                        endRadius: 320
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    
                    if weather.hasSunRays {
                        SunRayOverlay(time: t)
                    }

                    if weather.hasRain {
                        RainOverlay(
                            time: t,
                            intensity: weather.rainIntensity,
                            surfaceLevel: 0.36,
                            surfaceAmplitude: 10 * weather.waveIntensity,
                            surfaceFrequency: 2.0,
                            surfacePhase: t * 1.8
                        )
                    }

                    // Far wave layer near surface.
                    WaveShape(
                        amplitude: 12 * weather.waveIntensity,
                        frequency: 1.2,
                        phase: t * 0.8,
                        verticalOffset: geo.size.height * 0.26
                    )
                    .fill(weather.waveColor.opacity(0.14))

                    // Mid wave layer.
                    WaveShape(
                        amplitude: 16 * weather.waveIntensity,
                        frequency: 1.7,
                        phase: t * 1.2,
                        verticalOffset: geo.size.height * 0.31
                    )
                    .fill(weather.waveColor.opacity(0.2))

                    // Front wave layer.
                    WaveShape(
                        amplitude: 10 * weather.waveIntensity,
                        frequency: 2.0,
                        phase: t * 1.8,
                        verticalOffset: geo.size.height * 0.36
                    )
                    .fill(weather.waveColor.opacity(0.24))

                    BubbleFieldView(time: t, bubbleCount: weather.bubbleCount, surfaceLevel: 0.40)
                    FishSchoolView(time: t, hasStorm: weather.hasStorm)

                    if weather.hasStorm {
                        LightningPulseView(time: t)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BubbleFieldView: View {
    let time: Double
    let bubbleCount: Int
    let surfaceLevel: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<bubbleCount, id: \.self) { i in
                    let seed = Double(i) * 0.77
                    let x = geo.size.width * (0.08 + 0.84 * normalized(sin(seed * 4.2)))
                    let drift = 20.0 * sin(time * 0.4 + seed)
                    let rise = normalized(sin((time * 0.12) + seed * 2.4))
                    let depthRange = 0.96 - surfaceLevel
                    let y = geo.size.height * (0.96 - rise * depthRange)
                    let size = CGFloat(5 + (i % 5) * 2)

                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: size, height: size)
                        .position(x: x + drift, y: y)
                }
            }
        }
    }

    private func normalized(_ value: Double) -> Double {
        (value + 1.0) / 2.0
    }
}

private struct FishSchoolView: View {
    let time: Double
    let hasStorm: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    let seed = Double(i) * 1.37
                    let speed = (hasStorm ? 18.0 : 12.0) + Double(i)
                    let swim = (time * speed + seed * 130).truncatingRemainder(dividingBy: geo.size.width + 180)
                    let x = swim - 90
                    let yBand = 0.46 + Double(i % 3) * 0.10
                    let bob = sin(time * 1.2 + seed) * 8
                    let y = geo.size.height * yBand + bob
                    let scale = 0.55 + Double(i % 4) * 0.12
                    let opacity = hasStorm ? 0.08 : 0.14

                    FishShape()
                        .fill(Color.white.opacity(opacity))
                        .frame(width: 46 * scale, height: 22 * scale)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

private struct FishShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let body = CGRect(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.2, width: rect.width * 0.62, height: rect.height * 0.6)
        path.addEllipse(in: body)

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.15))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.15))
        path.closeSubpath()

        return path
    }
}

private struct LightningPulseView: View {
    let time: Double

    var body: some View {
        let pulse = max(0, sin(time * 2.4))
        let flash = pulse > 0.985 ? pulse : 0

        return LinearGradient(
            colors: [
                Color.white.opacity(0.26 * flash),
                Color.cyan.opacity(0.14 * flash),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .center
        )
        .blendMode(.screen)
    }
}

private struct SunRayOverlay: View {
    let time: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let width = geo.size.width * (0.20 + Double(i) * 0.06)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: width, height: geo.size.height * 0.7)
                        .rotationEffect(.degrees(-15 + Double(i * 10)))
                        .offset(x: -geo.size.width * 0.25 + Double(i) * 60 + sin(time * 0.25 + Double(i)) * 8, y: -geo.size.height * 0.2)
                }
            }
        }
        .blendMode(.screen)
    }
}

private struct RainOverlay: View {
    let time: Double
    let intensity: Double
    let surfaceLevel: Double
    let surfaceAmplitude: CGFloat
    let surfaceFrequency: CGFloat
    let surfacePhase: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<30, id: \.self) { i in
                    let seed = Double(i) * 1.97
                    let x = geo.size.width * normalized(sin(seed * 3.1))
                    let fall = (time * (280 * intensity) + seed * 90).truncatingRemainder(dividingBy: geo.size.height + 80)
                    let y = fall - 40
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 1.6, height: 16 + intensity * 8)
                        .rotationEffect(.degrees(18))
                        .position(x: x, y: y)
                }
            }
            .mask(
                SkyAboveWaveMask(
                    verticalOffset: geo.size.height * surfaceLevel,
                    amplitude: surfaceAmplitude,
                    frequency: surfaceFrequency,
                    phase: surfacePhase
                )
                .fill(Color.white)
            )
        }
        .blendMode(.plusLighter)
    }
    
    private func normalized(_ value: Double) -> Double {
        (value + 1.0) / 2.0
    }
}

private struct SkyAboveWaveMask: Shape {
    var verticalOffset: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        let width = rect.width
        path.addLine(to: CGPoint(x: rect.maxX, y: verticalOffset))

        stride(from: width, through: 0, by: -1).forEach { x in
            let relativeX = x / width
            let radians = relativeX * .pi * 2 * frequency + phase
            let y = verticalOffset + sin(radians) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }
}

private struct OceanWeatherProfile {
    let waveIntensity: CGFloat
    let bubbleCount: Int
    let waveColor: Color
    let glowColor: Color
    let glowOpacity: Double
    let hasStorm: Bool
    let hasRain: Bool
    let rainIntensity: Double
    let hasSunRays: Bool

    init(state: String) {
        switch state {
        case "Calm Waters":
            waveIntensity = 0.8
            bubbleCount = 14
            waveColor = .teal
            glowColor = .cyan
            glowOpacity = 0.2
            hasStorm = false
            hasRain = false
            rainIntensity = 0
            hasSunRays = true
        case "Steady Current":
            waveIntensity = 1.0
            bubbleCount = 12
            waveColor = .blue
            glowColor = .cyan
            glowOpacity = 0.18
            hasStorm = false
            hasRain = false
            rainIntensity = 0
            hasSunRays = true
        case "Choppy Tide":
            waveIntensity = 1.35
            bubbleCount = 8
            waveColor = .indigo
            glowColor = .blue
            glowOpacity = 0.14
            hasStorm = false
            hasRain = false
            rainIntensity = 0
            hasSunRays = false
        default:
            waveIntensity = 1.65
            bubbleCount = 6
            waveColor = .purple
            glowColor = .indigo
            glowOpacity = 0.1
            hasStorm = true
            hasRain = true
            rainIntensity = 1.0
            hasSunRays = false
        }
    }
}

private struct WaveShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: Double
    var verticalOffset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: verticalOffset))

        let width = rect.width
        stride(from: 0, through: width, by: 1).forEach { x in
            let relativeX = x / width
            let radians = relativeX * .pi * 2 * frequency + phase
            let y = verticalOffset + sin(radians) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
