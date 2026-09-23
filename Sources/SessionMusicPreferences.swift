import Foundation

enum SessionMusicPreferences {
    // Retain the existing key for countdowns so upgrades preserve that choice.
    static let countdownKey = "autoPlayFocusAudio"
    static let stopwatchKey = "autoPlayStopwatchAudio"

    static func migrate(in defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: stopwatchKey) == nil else { return }
        let previousChoice = defaults.object(forKey: countdownKey) as? Bool ?? true
        defaults.set(previousChoice, forKey: stopwatchKey)
    }

    static func shouldStart(mode: TimerEngine.Mode, countdown: Bool, stopwatch: Bool) -> Bool {
        mode == .countdown ? countdown : stopwatch
    }
}

/// Shared by the screen and integration tests so both modes use the same path.
@MainActor
enum SessionPlayback {
    static func reset(timer: TimerEngine, audio: AudioPlayer, automaticMusic: Bool) {
        if automaticMusic { audio.pause() }
        timer.reset()
    }

    static func start(timer: TimerEngine, audio: AudioPlayer, automaticMusic: Bool) {
        timer.start()
        if automaticMusic, audio.isAvailable { audio.play() }
    }

    static func pause(timer: TimerEngine, audio: AudioPlayer, automaticMusic: Bool) {
        timer.pause()
        if automaticMusic { audio.pause() }
    }
}
