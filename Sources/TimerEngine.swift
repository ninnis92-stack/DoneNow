import Foundation
import SwiftUI

class TimerEngine: ObservableObject {
    enum Mode: String {
        case countdown
        case stopwatch
    }

    @Published var timeRemaining: TimeInterval
    @Published var elapsedTime: TimeInterval
    @Published var isRunning: Bool
    @Published var isFinished: Bool
    @Published var selectedDuration: TimeInterval
    @Published private(set) var mode: Mode
    
    private var displayLink: CADisplayLink?
    private var endDate: Date?
    private lazy var displayTarget = TimerDisplayTarget(owner: self)

    private static func validDuration(_ value: TimeInterval) -> TimeInterval {
        value.isFinite && value > 0 ? min(value, 10_800) : 1500
    }
    
    init(duration: TimeInterval) {
        self.selectedDuration = Self.validDuration(duration)
        self.timeRemaining = Self.validDuration(duration)
        self.elapsedTime = 0
        self.isRunning = false
        self.isFinished = false
        self.mode = .countdown
    }
    
    func setDuration(_ newDuration: TimeInterval) {
        pause()
        selectedDuration = Self.validDuration(newDuration)
        timeRemaining = selectedDuration
        elapsedTime = 0
        isFinished = false
    }

    func setMode(_ newMode: Mode) {
        guard mode != newMode else { return }
        pause()
        mode = newMode
        timeRemaining = selectedDuration
        elapsedTime = 0
        isFinished = false
    }

    // Keep an active session intact; reconcile an idle/paused session when
    // StoreKit finishes restoring or revokes the selected premium theme.
    func reconcileMode(wantsStopwatch: Bool) {
        guard !isRunning, !isFinished else { return }
        setMode(wantsStopwatch ? .stopwatch : .countdown)
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        isFinished = false
        endDate = mode == .countdown
            ? Date().addingTimeInterval(timeRemaining)
            : Date().addingTimeInterval(-elapsedTime)
        displayLink = CADisplayLink(target: displayTarget, selector: #selector(TimerDisplayTarget.tick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func pause() {
        if isRunning, let endDate {
            if mode == .countdown {
                timeRemaining = max(0, endDate.timeIntervalSinceNow)
            } else {
                elapsedTime = max(0, -endDate.timeIntervalSinceNow)
            }
        }
        isRunning = false
        endDate = nil
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func reset() {
        pause()
        timeRemaining = selectedDuration
        elapsedTime = 0
        isFinished = false
    }
    
    deinit { displayLink?.invalidate() }

    fileprivate func updateTimer() {
        guard let currentEndDate = endDate else { return }

        if mode == .stopwatch {
            elapsedTime = max(0, -currentEndDate.timeIntervalSinceNow)
            return
        }

        timeRemaining = max(0, currentEndDate.timeIntervalSinceNow)

        if timeRemaining == 0 {
            timeRemaining = 0
            isRunning = false
            isFinished = true
            endDate = nil
            displayLink?.invalidate()
            displayLink = nil
        }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let safe = time.isFinite ? min(315_360_000, max(0, time)) : 0
        let rounded = Int(mode == .stopwatch ? floor(safe) : ceil(safe))
        let minutes = rounded / 60
        let seconds = rounded % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var displayTime: TimeInterval {
        mode == .stopwatch ? elapsedTime : timeRemaining
    }

    var sessionElapsed: TimeInterval {
        mode == .stopwatch ? max(0, elapsedTime) : max(0, selectedDuration - timeRemaining)
    }
}

private final class TimerDisplayTarget: NSObject {
    weak var owner: TimerEngine?
    init(owner: TimerEngine) { self.owner = owner }
    @objc func tick() { owner?.updateTimer() }
}
