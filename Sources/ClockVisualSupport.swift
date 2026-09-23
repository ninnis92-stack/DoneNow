import SwiftUI

enum ClockGeometry {
    /// Keep turns unwrapped so crossing twelve never reverses the hand.
    static func chronographTurns(elapsed: TimeInterval, period: TimeInterval) -> Double {
        guard elapsed.isFinite, period.isFinite, period > 0 else { return 0 }
        return max(0, elapsed) / period
    }

    static func clamp(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }

    static func orbit(_ progress: Double) -> CGPoint {
        let angle = clamp(progress) * 2 * Double.pi - Double.pi / 2
        return CGPoint(x: cos(angle) * 118, y: sin(angle) * 118)
    }

    static func birdReveal(_ progress: Double) -> Double {
        clamp((clamp(progress) - 0.86) / 0.14)
    }

    static func stopwatchStatus(time: String, running: Bool) -> String {
        if running { return "ELAPSED" }
        return time.contains(where: { ($0.wholeNumberValue ?? 0) > 0 }) ? "PAUSED" : "READY"
    }
}

/// One source of geometry for both the lower pile and its falling-grain endpoint.
struct HourglassGeometry {
    let progress: Double
    var upperHeight: CGFloat { 88 * sqrt(1 - ClockGeometry.clamp(progress)) }
    var lowerHeight: CGFloat { 88 * ClockGeometry.clamp(progress) }
    var lowerApex: CGFloat { 90 - lowerHeight }
    var lowerCenter: CGFloat { 90 - lowerHeight / 2 }
}

/// Decoration time advances only while the session runs; pause/resume has no phase jump.
struct ClockMotion {
    private var accumulated: TimeInterval = 0
    private var started: Date?
    func phase(at date: Date) -> TimeInterval {
        accumulated + (started.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }
    mutating func setRunning(_ running: Bool, at date: Date) {
        if running {
            if started == nil { started = date }
        } else if started != nil {
            accumulated = phase(at: date)
            started = nil
        }
    }
    mutating func reset(running: Bool, at date: Date) {
        accumulated = 0
        started = running ? date : nil
    }
}

@MainActor
final class FlipDigitState: ObservableObject {
    @Published private(set) var displayedValue: String
    @Published private(set) var angle = 0.0
    private var pending: Task<Void, Never>?

    init(_ value: String) { displayedValue = value }

    func update(_ value: String, animated: Bool) {
        // Cancel BEFORE checking equality: a reset can return to the visible old digit
        // while a delayed flip to another digit is still pending.
        pending?.cancel()
        pending = nil
        guard animated, value != displayedValue else {
            displayedValue = value
            angle = 0
            return
        }
        withAnimation(.easeIn(duration: 0.17)) { angle = 88 }
        pending = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(170)) }
            catch { return }
            guard !Task.isCancelled, let self else { return }
            self.displayedValue = value
            self.angle = -88
            withAnimation(.easeOut(duration: 0.17)) { self.angle = 0 }
        }
    }
    deinit { pending?.cancel() }
}

struct PendulumAssembly: View {
    let length: CGFloat
    let color: Color
    let angle: Double
    var body: some View {
        ZStack(alignment: .top) {
            Capsule().fill(color.opacity(0.65)).frame(width: 3, height: length)
            Circle().fill(color).frame(width: 28, height: 28).offset(y: length - 14)
        }
        .frame(width: 60, height: length + 14, alignment: .top)
        .rotationEffect(.degrees(angle), anchor: .top)
    }
}

struct MechanicalDial: View {
    let progress: Double
    let color: Color
    let diameter: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.35))
                .overlay(Circle().stroke(color.opacity(0.65), lineWidth: 2))
            ForEach(0..<12) { i in
                Capsule().fill(color.opacity(0.7)).frame(width: 2, height: 7)
                    .offset(y: -(diameter / 2 - 10))
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            Capsule().fill(color.opacity(0.65)).frame(width: 3, height: diameter * 0.34)
                .offset(y: -diameter * 0.17)
                .rotationEffect(.degrees(progress * 360))
        }.frame(width: diameter, height: diameter)
    }
}

struct ChronographSubdial: View {
    let label: String
    let fraction: Double
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.4), lineWidth: 1)
            Capsule().fill(color.opacity(0.8)).frame(width: 1.5, height: 18)
                .offset(y: -9).rotationEffect(.degrees(fraction * 360))
            Text(label).font(.system(size: 7, weight: .semibold)).offset(y: 15)
                .foregroundStyle(color.opacity(0.7))
        }.frame(width: 55, height: 55)
    }
}
