import XCTest
import UIKit
import SwiftUI
private struct MusicChooserStressHost: View {
    @ObservedObject var timer: TimerEngine
    let audio: AudioPlayer
    @State private var presented = true
    var body: some View {
        Text(timer.formatTime(timer.displayTime))
            .sheet(isPresented: $presented) {
                SoundscapePickerView(audio: audio, hasPro: true, requestPro: {})
            }
    }
}
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
@testable import DoneNow

final class DoneNowTests: XCTestCase {
    @MainActor func testClockHandsUseSessionTimeAcrossPauseResetAndModeChanges() {
        let timer = TimerEngine(duration: 1500)
        XCTAssertEqual(timer.sessionElapsed, 0)
        timer.timeRemaining = 1439
        XCTAssertEqual(timer.sessionElapsed, 61)
        timer.pause()
        XCTAssertEqual(timer.sessionElapsed, 61)
        timer.reset()
        XCTAssertEqual(timer.sessionElapsed, 0)
        timer.setMode(.stopwatch)
        timer.elapsedTime = 72
        XCTAssertEqual(timer.sessionElapsed, 72)
        timer.reset()
        XCTAssertEqual(timer.sessionElapsed, 0)
        timer.setMode(.countdown)
        timer.timeRemaining = 0
        XCTAssertEqual(timer.sessionElapsed, 1500)
    }
    func testChronographHandsAdvanceClockwiseAcrossRollovers() {
        for period in [60.0, 3600.0] {
            let samples = [0.0, 1, 59, 60, 61, 3599, 3600, 3601, 10800]
            let turns = samples.map { ClockGeometry.chronographTurns(elapsed: $0, period: period) }
            for index in 1..<turns.count { XCTAssertGreaterThan(turns[index], turns[index - 1]) }
            XCTAssertEqual(ClockGeometry.chronographTurns(elapsed: period, period: period), 1)
            XCTAssertEqual(ClockGeometry.chronographTurns(elapsed: 0, period: period), 0)
        }
    }

    func testChronographRejectsInvalidElapsedTime() {
        for elapsed in [-1.0, Double.nan, .infinity] {
            XCTAssertEqual(ClockGeometry.chronographTurns(elapsed: elapsed, period: 60), 0)
        }
        XCTAssertEqual(ClockGeometry.chronographTurns(elapsed: 10, period: 0), 0)
    }

    @MainActor func testLargeTextHouseBannerDoesNotConsumePhoneScreen() {
        let host = UIHostingController(rootView: AdBannerSlot(consentReady: false, statusMessage: nil, retry: {}, upgrade: {})
            .environment(\.dynamicTypeSize, .accessibility5))
        let size = host.sizeThatFits(in: CGSize(width: 320, height: 2000))
        XCTAssertLessThan(size.height, 180)
        XCTAssertLessThanOrEqual(size.width, 320)
    }
    @MainActor func testCompactPhoneLargeTextVisualSnapshot() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let host = UIHostingController(rootView: MainFocusView().environmentObject(AdMobCoordinator.shared).environment(\.dynamicTypeSize, .accessibility3))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in host.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        try image.pngData()?.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("compact-large-text.png"))
        XCTAssertEqual(host.view.bounds.width, 320)
    }
    @MainActor func testCosmeticClockContactSheets() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for progress in [0.0, 0.5, 1.0] {
            let sheet = VStack(spacing: 8) {
                ForEach(0..<5) { row in
                    HStack(spacing: 8) {
                        ForEach(Array(Theme.allCases.enumerated()).filter { $0.offset / 4 == row }, id: \.offset) { _, theme in
                            VStack {
                                Text(theme.rawValue).font(.system(size: 16)).foregroundStyle(.white)
                                ClockFaceView(theme: theme, progress: progress, time: progress == 1 ? "00:00" : "180:00", isRunning: false, sessionElapsed: 10800 * progress)
                            }.frame(width: 300, height: 315).background(theme.backgroundColor)
                        }
                    }
                }
            }.padding(8).background(.black).preferredColorScheme(.dark)
            let host = UIHostingController(rootView: sheet)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 1240, height: 1630)
            window.rootViewController = host
            window.isHidden = false
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in host.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            try image.pngData()?.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("clocks-\(Int(progress * 100)).png"))
            window.isHidden = true
        }
    }
    func testStopwatchRoundsDownWhileCountdownRoundsUpAndNonfiniteIsSafe() {
        let timer = TimerEngine(duration: 60)
        XCTAssertEqual(timer.formatTime(0.01), "00:01")
        timer.setMode(.stopwatch)
        XCTAssertEqual(timer.formatTime(0.99), "00:00")
        XCTAssertEqual(timer.formatTime(59.99), "00:59")
        XCTAssertEqual(timer.formatTime(60), "01:00")
        for value in [Double.nan, .infinity, -.infinity, -1] {
            XCTAssertEqual(timer.formatTime(value), "00:00")
        }
    }

    func testInvalidDurationsAreSanitized() {
        for value in [Double.nan, .infinity, -.infinity, -1, 0] {
            let timer = TimerEngine(duration: value)
            XCTAssertEqual(timer.selectedDuration, 1500)
            timer.setDuration(value)
            XCTAssertEqual(timer.timeRemaining, 1500)
        }
        XCTAssertEqual(TimerEngine(duration: 999999).selectedDuration, 10800)
    }

    @MainActor func testRunningTimerDoesNotRetainItselfAfterScreenRemoval() {
        weak var reference: TimerEngine?
        autoreleasepool {
            let timer = TimerEngine(duration: 60)
            reference = timer
            timer.start()
        }
        XCTAssertNil(reference)
    }

    @MainActor func testImportWhilePlayingPreservesVolumeMuteAndPlaybackAndCanBeRemoved() throws {
        let audio = AudioPlayer()
        defer { audio.stop() }
        let source = try XCTUnwrap(Bundle.main.url(forResource: "calm_ocean", withExtension: "mp3"))
        audio.selectBuiltInSoundscape(.ocean)
        audio.setVolume(0.23)
        audio.toggleMute()
        audio.play()
        audio.importAudio(from: source)
        XCTAssertNotNil(audio.selectedImportedTrack)
        XCTAssertTrue(audio.isPlaying)
        XCTAssertTrue(audio.isMuted)
        XCTAssertEqual(audio.volume, 0.23, accuracy: 0.001)
        let id = audio.selectedImportedTrackID
        audio.removeImportedAudio()
        XCTAssertNil(audio.selectedImportedTrackID)
        XCTAssertFalse(audio.importedTracks.contains { $0.id == id })
        XCTAssertTrue(audio.isAvailable)
        audio.importAudio(from: source)
        XCTAssertFalse(audio.isPlaying)
        audio.removeImportedAudio()
    }

    @MainActor func testMissingOrUnsafeImportSelectionPreservesExistingPlayback() {
        let audio = AudioPlayer()
        defer { audio.stop() }
        audio.selectBuiltInSoundscape(.ocean)
        audio.play()
        for name in ["missing-\(UUID()).mp3", "../outside.mp3", "/tmp/outside.mp3"] {
            audio.selectImportedTrack(.init(id: UUID(), title: "Unavailable", fileName: name))
            XCTAssertEqual(audio.selectedSoundscape, .ocean)
            XCTAssertTrue(audio.isPlaying)
            XCTAssertNotNil(audio.errorMessage)
        }
    }

    @MainActor func testCorruptImportDoesNotStopPreviousAudio() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("audit-\(UUID()).mp3")
        try Data("invalid audio".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let audio = AudioPlayer()
        defer { audio.stop() }
        audio.selectBuiltInSoundscape(.ocean)
        audio.play()
        audio.importAudio(from: file)
        XCTAssertTrue(audio.isPlaying)
        XCTAssertEqual(audio.selectedSoundscape, .ocean)
        XCTAssertNotNil(audio.errorMessage)
    }
    @MainActor func testActualFocusScreenRemainsOpenAfterCountdownCompletion() async throws {
        let savedTheme = UserDefaults.standard.object(forKey: "selectedThemeName")
        UserDefaults.standard.set(Theme.analog.rawValue, forKey: "selectedThemeName")
        defer {
            if let savedTheme { UserDefaults.standard.set(savedTheme, forKey: "selectedThemeName") }
            else { UserDefaults.standard.removeObject(forKey: "selectedThemeName") }
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let previousIDs = Set(FocusHistoryStore.shared.sessions.map(\.id))
        let timer = TimerEngine(duration: 0.2)
        let host = UIHostingController(rootView: MainFocusView(timer: timer).environmentObject(AdMobCoordinator.shared))
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            host.dismiss(animated: false)
            timer.pause()
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
            for session in FocusHistoryStore.shared.sessions where !previousIDs.contains(session.id) { FocusHistoryStore.shared.delete(session) }
        }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(timer.mode, .countdown)
        timer.start()
        try await Task.sleep(for: .milliseconds(1000))
        XCTAssertTrue(timer.isFinished)
        XCTAssertFalse(window.isHidden)
        let completion = try XCTUnwrap(host.presentedViewController)
        try await Task.sleep(for: .milliseconds(750))
        XCTAssertTrue(host.presentedViewController === completion)
        XCTAssertNotNil(host.view.window)
    }
    @MainActor func testCompletionAlarmBufferAndNodeMatchAtBothCommonSampleRates() {
        for rate in [44_100.0, 48_000.0] {
            let alarm = CompletionAlarmPlayer(sampleRate: rate)
            XCTAssertEqual(alarm.alarmSampleRate, rate)
            XCTAssertEqual(alarm.nodeSampleRate, rate)
            alarm.play(for: .analog)
            XCTAssertEqual(alarm.nodeSampleRate, alarm.alarmSampleRate)
            alarm.stop()
        }
    }
    @MainActor func testCountdownNaturallyCompletesAndEveryThemeAlarmPlaysWithoutTermination() async throws {
        let timer = TimerEngine(duration: 0.1)
        timer.start()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(timer.isFinished)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.timeRemaining, 0)
        let alarm = CompletionAlarmPlayer()
        defer { alarm.stop(); timer.pause() }
        for theme in Theme.allCases {
            alarm.play(for: theme)
            try await Task.sleep(for: .milliseconds(100))
            alarm.stop()
        }
    }
    @MainActor func testNotificationRevisionsRejectCancellationAndLateAdds() {
        var removed: [String] = []
        let gate = NotificationRequestGate { removed += $0 }
        let prefix = "test.\(UUID())"
        let old = gate.begin(prefix: prefix)
        let latest = gate.begin(prefix: prefix)
        XCTAssertFalse(gate.isCurrent(old))
        XCTAssertTrue(gate.isCurrent(latest))
        removed = []
        gate.didAdd(prefix: prefix, token: old)
        XCTAssertEqual(removed, [gate.identifier(prefix: prefix, token: old)])
        XCTAssertFalse(removed.contains(gate.identifier(prefix: prefix, token: latest)))
        gate.invalidate(legacyIdentifier: prefix)
        XCTAssertFalse(gate.isCurrent(latest))
    }

    @MainActor func testNotificationDeadlineAccountsForPermissionDelay() {
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(NotificationRequestGate.remaining(until: start.addingTimeInterval(60), now: start.addingTimeInterval(20)), 40)
        XCTAssertNil(NotificationRequestGate.remaining(until: start, now: start))
        XCTAssertNil(NotificationRequestGate.remaining(until: start, now: start.addingTimeInterval(1)))
    }

    @MainActor func testNotificationCancellationSurvivesNewGateInstance() {
        let prefix = "test.\(UUID())"
        let first = NotificationRequestGate { _ in }
        let token = first.begin(prefix: prefix)
        var removed: [String] = []
        let next = NotificationRequestGate { removed += $0 }
        next.invalidate(legacyIdentifier: prefix)
        XCTAssertTrue(removed.contains(first.identifier(prefix: prefix, token: token)))
    }

    @MainActor func testEntitlementModeReconciliationPreservesRunningSession() {
        let timer = TimerEngine(duration: 60)
        timer.reconcileMode(wantsStopwatch: true)
        XCTAssertEqual(timer.mode, .stopwatch)
        timer.start()
        timer.reconcileMode(wantsStopwatch: false)
        XCTAssertEqual(timer.mode, .stopwatch)
        XCTAssertTrue(timer.isRunning)
        timer.pause()
        timer.reconcileMode(wantsStopwatch: false)
        XCTAssertEqual(timer.mode, .countdown)
    }

    @MainActor func testPremiumAudioReconcilesOnlyAfterEntitlementResolves() {
        let audio = AudioPlayer()
        defer { audio.stop() }
        audio.selectBuiltInSoundscape(.rain)
        audio.play()
        audio.reconcileEntitlement(hasPro: false, resolved: false)
        XCTAssertEqual(audio.selectedSoundscape, .rain)
        audio.reconcileEntitlement(hasPro: false, resolved: true)
        XCTAssertEqual(audio.selectedSoundscape, .atmosphere)
        XCTAssertTrue(audio.isPlaying)
        audio.selectBuiltInSoundscape(.rain)
        XCTAssertEqual(audio.selectedSoundscape, .atmosphere)
        audio.reconcileEntitlement(hasPro: true, resolved: true)
        audio.selectBuiltInSoundscape(.rain)
        XCTAssertEqual(audio.selectedSoundscape, .rain)
    }

    @MainActor func testInterruptionHonorsResumePermissionAndExplicitPauseStop() {
        let audio = AudioPlayer()
        defer { audio.stop() }
        audio.play()
        audio.handleInterruption(began: true, shouldResume: false)
        audio.handleInterruption(began: false, shouldResume: false)
        XCTAssertFalse(audio.isPlaying)
        audio.play()
        audio.handleInterruption(began: true, shouldResume: false)
        audio.pause()
        audio.handleInterruption(began: false, shouldResume: true)
        XCTAssertFalse(audio.isPlaying)
        audio.play()
        audio.handleInterruption(began: true, shouldResume: false)
        audio.stop()
        audio.handleInterruption(began: false, shouldResume: true)
        XCTAssertFalse(audio.isPlaying)
        audio.play()
        audio.handleInterruption(began: true, shouldResume: false)
        audio.handleInterruption(began: false, shouldResume: true)
        XCTAssertTrue(audio.isPlaying)
    }

    @MainActor func testBatchHistoryDeletionUsesOriginalOffsets() {
        let sessions = (0..<4).map { FocusSession(id: UUID(), completedAt: Date(), duration: 60, intention: "\($0)", theme: "test") }
        XCTAssertEqual(FocusHistoryStore.removing(IndexSet([0, 1]), from: sessions).map(\.intention), ["2", "3"])
        XCTAssertEqual(FocusHistoryStore.removing(IndexSet([1, 3, 99]), from: sessions).map(\.intention), ["0", "2"])
        XCTAssertTrue(FocusHistoryStore.removing(IndexSet(0..<4), from: sessions).isEmpty)
    }

    @MainActor func testResetPausesAutomaticMusicButPreservesIndependentPlayback() {
        let audio = AudioPlayer()
        let timer = TimerEngine(duration: 60)
        defer { audio.stop(); timer.pause() }
        for mode in [TimerEngine.Mode.countdown, .stopwatch] {
            for automatic in [true, false] {
                timer.setMode(mode)
                timer.start()
                audio.play()
                SessionPlayback.reset(timer: timer, audio: audio, automaticMusic: automatic)
                XCTAssertFalse(timer.isRunning)
                XCTAssertEqual(timer.elapsedTime, 0)
                XCTAssertEqual(audio.isPlaying, !automatic)
            }
        }
    }

    @MainActor func testCorruptImportedSelectionFallsBackWithConsistentMetadata() throws {
        let defaults = UserDefaults.standard
        let keys = ["importedFocusTracks", "selectedImportedFocusTrackID", "useImportedFocusAudio", "selectedBuiltInSoundscape"]
        let previous = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, previous) { if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) } } }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ImportedAudio")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let track = AudioPlayer.ImportedTrack(id: UUID(), title: "Corrupt test", fileName: "audit-\(UUID()).mp3")
        let file = folder.appendingPathComponent(track.fileName)
        try Data("not audio".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        defaults.set(try JSONEncoder().encode([track]), forKey: keys[0])
        defaults.set(track.id.uuidString, forKey: keys[1])
        defaults.set(true, forKey: keys[2])
        defaults.set("ocean", forKey: keys[3])
        let audio = AudioPlayer()
        defer { audio.stop() }
        XCTAssertNil(audio.selectedImportedTrackID)
        XCTAssertEqual(audio.trackName, AudioPlayer.BuiltInSoundscape.ocean.title)
        XCTAssertTrue(audio.isAvailable)
        XCTAssertFalse(defaults.bool(forKey: keys[2]))
    }
    @MainActor func testMusicChooserRemainsPresentedDuringLiveTimerUpdatesAndPlayback() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let timer = TimerEngine(duration: 1500)
        let audio = AudioPlayer()
        let controller = UIHostingController(rootView: MusicChooserStressHost(timer: timer, audio: audio))
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { timer.pause(); audio.stop(); window.isHidden = true; window.rootViewController = nil }
        audio.selectBuiltInSoundscape(.rain)
        audio.play()
        timer.start()
        try await Task.sleep(for: .milliseconds(800))
        let chooser = try XCTUnwrap(controller.presentedViewController)
        for sound in AudioPlayer.BuiltInSoundscape.allCases {
            audio.selectBuiltInSoundscape(sound)
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertTrue(controller.presentedViewController === chooser)
            XCTAssertTrue(audio.isPlaying)
            XCTAssertTrue(timer.isRunning)
            XCTAssertEqual(audio.selectedSoundscape, sound)
        }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Persistent-music-chooser-during-countdown"
        attachment.lifetime = .keepAlways
        add(attachment)
        try image.pngData()?.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("music-chooser.png"))
    }

    @MainActor func testBothSessionModesStartPauseResumeAndSwitchLiveSoundscapes() {
        let audio = AudioPlayer()
        let timer = TimerEngine(duration: 1500)
        defer { audio.stop(); timer.pause() }
        audio.selectBuiltInSoundscape(.rain)
        audio.setVolume(0.31)
        for countdown in [false, true] {
            for stopwatch in [false, true] {
                for mode in [TimerEngine.Mode.countdown, .stopwatch] {
                    audio.pause()
                    timer.setMode(mode)
                    let enabled = SessionMusicPreferences.shouldStart(mode: mode, countdown: countdown, stopwatch: stopwatch)
                    SessionPlayback.start(timer: timer, audio: audio, automaticMusic: enabled)
                    XCTAssertTrue(timer.isRunning)
                    XCTAssertEqual(audio.isPlaying, enabled)
                    SessionPlayback.pause(timer: timer, audio: audio, automaticMusic: enabled)
                    XCTAssertFalse(timer.isRunning)
                    XCTAssertFalse(audio.isPlaying)
                    SessionPlayback.start(timer: timer, audio: audio, automaticMusic: enabled)
                    XCTAssertEqual(audio.isPlaying, enabled)
                    // Manual playback remains available even when automatic start is off.
                    if !enabled { audio.play() }
                    for sound in AudioPlayer.BuiltInSoundscape.allCases {
                        audio.selectBuiltInSoundscape(sound)
                        XCTAssertTrue(audio.isPlaying, "Stopped switching to \(sound.title)")
                        XCTAssertTrue(timer.isRunning)
                        XCTAssertEqual(timer.mode, mode)
                        XCTAssertEqual(audio.volume, 0.31, accuracy: 0.001)
                    }
                    SessionPlayback.pause(timer: timer, audio: audio, automaticMusic: enabled)
                    XCTAssertEqual(audio.isPlaying, !enabled, "Manual playback must not be changed by an opted-out session")
                }
            }
        }
    }

    @MainActor func testUnavailableAudioNeverPreventsEitherSessionStarting() {
        let audio = AudioPlayer()
        let timer = TimerEngine(duration: 1500)
        defer { audio.stop(); timer.pause() }
        audio.pause()
        audio.isAvailable = false
        for mode in [TimerEngine.Mode.countdown, .stopwatch] {
            timer.setMode(mode)
            SessionPlayback.start(timer: timer, audio: audio, automaticMusic: true)
            XCTAssertTrue(timer.isRunning)
            XCTAssertFalse(audio.isPlaying)
            SessionPlayback.pause(timer: timer, audio: audio, automaticMusic: true)
        }
    }

    func testSessionMusicChoicesAreIndependentForEveryCombination() {
        for countdown in [false, true] {
            for stopwatch in [false, true] {
                XCTAssertEqual(SessionMusicPreferences.shouldStart(mode: .countdown, countdown: countdown, stopwatch: stopwatch), countdown)
                XCTAssertEqual(SessionMusicPreferences.shouldStart(mode: .stopwatch, countdown: countdown, stopwatch: stopwatch), stopwatch)
            }
        }
    }

    func testSessionMusicMigrationPreservesLegacyChoiceAndNeverOverwritesStopwatch() throws {
        let suite = "DoneNowMusicTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for previousChoice in [false, true] {
            defaults.removeObject(forKey: SessionMusicPreferences.stopwatchKey)
            defaults.set(previousChoice, forKey: SessionMusicPreferences.countdownKey)
            SessionMusicPreferences.migrate(in: defaults)
            XCTAssertEqual(defaults.bool(forKey: SessionMusicPreferences.stopwatchKey), previousChoice)
            defaults.set(!previousChoice, forKey: SessionMusicPreferences.stopwatchKey)
            SessionMusicPreferences.migrate(in: defaults)
            XCTAssertEqual(defaults.bool(forKey: SessionMusicPreferences.stopwatchKey), !previousChoice)
            XCTAssertEqual(defaults.bool(forKey: SessionMusicPreferences.countdownKey), previousChoice)
        }
        defaults.removePersistentDomain(forName: suite)
        SessionMusicPreferences.migrate(in: defaults)
        XCTAssertTrue(defaults.bool(forKey: SessionMusicPreferences.stopwatchKey))
    }

    @MainActor func testFlipResetDuringAnimationCannotCommitStaleDigit() async throws {
        let state = FlipDigitState("6")
        state.update("5", animated: true)
        try await Task.sleep(for: .milliseconds(50))
        state.update("6", animated: true)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(state.displayedValue, "6")
        XCTAssertEqual(state.angle, 0)
    }

    @MainActor func testRapidFlipChangesAlwaysSettleOnLatestValue() async throws {
        let state = FlipDigitState("0")
        for n in 1...9 {
            state.update(String(n), animated: true)
            try await Task.sleep(for: .milliseconds(10))
        }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(state.displayedValue, "9")
        XCTAssertEqual(state.angle, 0)
    }

    @MainActor func testReducedMotionAndDisappearanceCancelPendingFlip() async throws {
        let state = FlipDigitState("1")
        state.update("2", animated: true)
        state.update("3", animated: false)
        XCTAssertEqual(state.displayedValue, "3")
        XCTAssertEqual(state.angle, 0)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(state.displayedValue, "3")
    }

    func testHourglassEmptyEndpointsAndStreamUseSameGeometry() {
        XCTAssertEqual(HourglassGeometry(progress: 0).lowerHeight, 0)
        XCTAssertEqual(HourglassGeometry(progress: 1).upperHeight, 0)
        for step in 0...100 {
            let p = Double(step) / 100
            let g = HourglassGeometry(progress: p)
            XCTAssertEqual(g.lowerApex, g.lowerCenter - g.lowerHeight / 2, accuracy: 0.00001)
            XCTAssertEqual(g.lowerCenter + g.lowerHeight / 2, 90, accuracy: 0.00001)
            // Upper triangular area changes quadratically with fill height;
            // the lower pile has fixed base and changes linearly with height.
            XCTAssertEqual(pow(g.upperHeight / 88, 2) + g.lowerHeight / 88, 1, accuracy: 0.00001)
        }
    }

    func testEarthCompletesOneOrbitAtCountdownEnd() {
        let points = [0.0, 0.25, 0.5, 0.75, 1].map(ClockGeometry.orbit)
        let expected = [CGPoint(x:0,y:-118), CGPoint(x:118,y:0), CGPoint(x:0,y:118), CGPoint(x:-118,y:0), CGPoint(x:0,y:-118)]
        for (actual, goal) in zip(points, expected) {
            XCTAssertEqual(actual.x, goal.x, accuracy: 0.000001)
            XCTAssertEqual(actual.y, goal.y, accuracy: 0.000001)
            XCTAssertLessThanOrEqual(hypot(actual.x, actual.y) + 18, 142.5)
        }
    }

    func testClockMotionFreezesResumesAndResetsWithoutJump() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        var motion = ClockMotion()
        motion.setRunning(true, at: start)
        motion.setRunning(true, at: start.addingTimeInterval(2))
        XCTAssertEqual(motion.phase(at:start.addingTimeInterval(10)),10)
        motion.setRunning(false, at:start.addingTimeInterval(10))
        XCTAssertEqual(motion.phase(at:start.addingTimeInterval(100)),10)
        motion.setRunning(true, at:start.addingTimeInterval(100))
        XCTAssertEqual(motion.phase(at:start.addingTimeInterval(105)),15)
        motion.reset(running:false,at:start.addingTimeInterval(110))
        XCTAssertEqual(motion.phase(at:start.addingTimeInterval(200)),0)
    }

    func testVisualGeometryHandlesOutOfRangeAndNonfiniteProgress() {
        for p in [-10.0, 0, 0.5, 1, 100, .infinity, -.infinity, .nan] {
            let clamped=ClockGeometry.clamp(p)
            XCTAssertTrue((0...1).contains(clamped))
            let g=HourglassGeometry(progress:p)
            XCTAssertTrue(g.upperHeight.isFinite)
            XCTAssertTrue(g.lowerApex.isFinite)
            XCTAssertTrue((0...1).contains(ClockGeometry.birdReveal(p)))
        }
        XCTAssertEqual(ClockGeometry.birdReveal(0),0)
        XCTAssertEqual(ClockGeometry.birdReveal(0.86),0)
        XCTAssertEqual(ClockGeometry.birdReveal(1),1)
    }

    func testStopwatchDistinguishesReadyPausedAndRunning() {
        XCTAssertEqual(ClockGeometry.stopwatchStatus(time:"00:00",running:false),"READY")
        XCTAssertEqual(ClockGeometry.stopwatchStatus(time:"12:30",running:false),"PAUSED")
        XCTAssertEqual(ClockGeometry.stopwatchStatus(time:"1000:00",running:false),"PAUSED")
        XCTAssertEqual(ClockGeometry.stopwatchStatus(time:"00:00",running:true),"ELAPSED")
    }

    @MainActor func testSwitchingSoundscapesPreservesPlayingPausedMuteAndVolume() {
        let audio = AudioPlayer()
        defer { audio.stop() }
        audio.selectBuiltInSoundscape(.atmosphere)
        audio.setVolume(0.35)
        audio.play()
        XCTAssertTrue(audio.isPlaying)
        for sound in AudioPlayer.BuiltInSoundscape.allCases {
            audio.selectBuiltInSoundscape(sound)
            XCTAssertTrue(audio.isPlaying, "Playback stopped for \(sound.title)")
            XCTAssertEqual(audio.selectedSoundscape, sound)
            XCTAssertEqual(audio.volume, 0.35, accuracy: 0.001)
        }
        if !audio.isMuted { audio.toggleMute() }
        audio.selectBuiltInSoundscape(.atmosphere)
        XCTAssertTrue(audio.isPlaying)
        XCTAssertTrue(audio.isMuted)
        audio.pause()
        audio.selectBuiltInSoundscape(.rain)
        XCTAssertFalse(audio.isPlaying)
    }

    @MainActor func testSameViewSurvivesRepeatedPortraitLandscapeResizing() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIHostingController(rootView: MainFocusView().environmentObject(AdMobCoordinator.shared))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        for size in [CGSize(width: 1032, height: 1376), CGSize(width: 1376, height: 1032), CGSize(width: 375, height: 1032), CGSize(width: 1032, height: 1376)] {
            window.frame = CGRect(origin: .zero, size: size)
            controller.view.frame = window.bounds
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            XCTAssertEqual(controller.view.bounds.size, size)
        }
    }

    @MainActor func testRenderIPadPortraitAndLandscape() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for size in [CGSize(width: 1032, height: 1376), CGSize(width: 1376, height: 1032)] {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            let controller = UIHostingController(rootView: MainFocusView().environmentObject(AdMobCoordinator.shared))
            window.rootViewController = controller
            window.isHidden = false
            controller.view.frame = window.bounds
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(size: size).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "iPad-\(Int(size.width))x\(Int(size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)
            try image.pngData()?.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("iPad-\(Int(size.width))x\(Int(size.height)).png"))
            XCTAssertEqual(controller.view.bounds.size, size)
            window.isHidden = true
        }
    }

    func testPhoneNeverUsesTabletLayoutEvenInLandscape() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 440, height: 956), CGSize(width: 956, height: 440)] {
            let layout = FocusLayout(size: size, isPad: false)
            XCTAssertFalse(layout.tablet)
            XCTAssertFalse(layout.columns)
            XCTAssertEqual(layout.clockSize, min(285, size.width - 40))
        }
    }

    func testIPadPortraitLandscapeAndSplitViewFit() {
        let portrait = FocusLayout(size: CGSize(width: 1032, height: 1376), isPad: true)
        XCTAssertTrue(portrait.tablet)
        XCTAssertFalse(portrait.columns)
        let landscape = FocusLayout(size: CGSize(width: 1376, height: 1032), isPad: true)
        XCTAssertTrue(landscape.columns)
        for width in [320.0, 375, 699, 700, 999, 1000, 1032, 1376] {
            let layout = FocusLayout(size: CGSize(width: width, height: 900), isPad: true)
            XCTAssertLessThanOrEqual(layout.clockSize, width - (layout.tablet ? 64 : 40))
            if width < 700 { XCTAssertFalse(layout.tablet) }
            if width < 1000 { XCTAssertFalse(layout.columns) }
        }
    }

    #if canImport(GoogleMobileAds)
    @MainActor func testBannerWaitsForWindowAndRequestsOnlyOnceAcrossReattachment() {
        let banner = AttachedBannerView(adSize: AdSizeBanner)
        var requests = 0
        banner.requestAd = { requests += 1 }
        banner.didMoveToWindow()
        XCTAssertEqual(requests, 0)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1032, height: 1376)
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.view.addSubview(banner)
        XCTAssertEqual(requests, 1)
        XCTAssertTrue(banner.rootViewController === controller)
        banner.removeFromSuperview()
        controller.view.addSubview(banner)
        XCTAssertEqual(requests, 1)
    }
    #endif

    func testRepeatedThemeModeSyncPreservesRunningCountdown() {
        let timer = TimerEngine(duration: 1500)
        timer.start()
        defer { timer.pause() }
        for _ in 0..<100 { timer.setMode(.countdown) }
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.selectedDuration, 1500)
        XCTAssertFalse(timer.isFinished)
    }

    func testBuiltInSoundscapesHaveUniqueStableTitles() {
        let soundscapes = AudioPlayer.BuiltInSoundscape.allCases
        XCTAssertEqual(soundscapes.count, 11)
        XCTAssertEqual(Set(soundscapes.map(\.rawValue)).count, 11)
        XCTAssertEqual(Set(soundscapes.map(\.title)).count, 11)
        XCTAssertEqual(Set(soundscapes.map(\.bundledResourceName)).count, 11)
        XCTAssertEqual(soundscapes.filter(\.isPro).count, 6)
        XCTAssertEqual(soundscapes.filter { !$0.isPro }.count, 5)
        XCTAssertEqual(soundscapes.map(\.ordinal), Array(1...11))
    }

    func testImportedTrackMetadataRoundTrips() throws {
        let original = AudioPlayer.ImportedTrack(
            id: UUID(),
            title: "My Focus Mix",
            fileName: "focus-music-unique.m4a"
        )

        let encoded = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([AudioPlayer.ImportedTrack].self, from: encoded)

        XCTAssertEqual(decoded, [original])
        XCTAssertEqual(decoded.first?.id, original.id)
        XCTAssertEqual(decoded.first?.fileName, original.fileName)
    }

    func testImportedTracksCanRepresentMultipleFilesWithoutColliding() {
        let first = AudioPlayer.ImportedTrack(id: UUID(), title: "Rain", fileName: "focus-music-first.mp3")
        let second = AudioPlayer.ImportedTrack(id: UUID(), title: "Rain", fileName: "focus-music-second.mp3")

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(first.fileName, second.fileName)
        XCTAssertEqual(Set([first.id, second.id]).count, 2)
    }

    func testStopwatchRemainsTheDedicatedProClockFace() {
        XCTAssertEqual(Theme.stopwatch.rawValue, "Time Trial")
        XCTAssertTrue(Theme.stopwatch.isPro)
        XCTAssertEqual(Theme.stopwatch.icon, "stopwatch.fill")
        XCTAssertEqual(Theme.stopwatch.alarmName, "Digital completion tone")
    }

    func testTimerStartsInCountdownModeByDefault() {
        let timer = TimerEngine(duration: 25 * 60)
        XCTAssertEqual(timer.mode, TimerEngine.Mode.countdown)
        XCTAssertFalse(timer.isRunning)
        XCTAssertGreaterThan(timer.timeRemaining, 0)
    }

    func testTimerFormattingClampsAndRoundsSafely() {
        let timer = TimerEngine(duration: 60)
        XCTAssertEqual(timer.formatTime(0), "00:00")
        XCTAssertEqual(timer.formatTime(-5), "00:00")
        XCTAssertEqual(timer.formatTime(59.1), "01:00")
        XCTAssertEqual(timer.formatTime(60), "01:00")
        XCTAssertEqual(timer.formatTime(3661), "61:01")
    }

    func testSwitchingToStopwatchResetsElapsedStateWithoutFinishing() {
        let timer = TimerEngine(duration: 90)
        timer.setMode(.stopwatch)

        XCTAssertEqual(timer.mode, .stopwatch)
        XCTAssertEqual(timer.elapsedTime, 0)
        XCTAssertEqual(timer.displayTime, 0)
        XCTAssertFalse(timer.isFinished)
        XCTAssertFalse(timer.isRunning)
    }

    func testChangingDurationResetsBothTimerModes() {
        let timer = TimerEngine(duration: 60)
        timer.setMode(.stopwatch)
        timer.setDuration(300)

        XCTAssertEqual(timer.selectedDuration, 300)
        XCTAssertEqual(timer.timeRemaining, 300)
        XCTAssertEqual(timer.elapsedTime, 0)
        XCTAssertFalse(timer.isFinished)
        XCTAssertFalse(timer.isRunning)
    }

    func testThemesHaveUniqueNamesAndOnlyTimeTrialIsStopwatch() {
        XCTAssertEqual(Set(Theme.allCases.map(\.rawValue)).count, Theme.allCases.count)
        XCTAssertEqual(Theme.allCases.filter { $0.rawValue == "Time Trial" }, [.stopwatch])
        XCTAssertTrue(Theme.stopwatch.isPro)
    }

    func testProUsesOnlyTheCurrentAppStoreProductID() {
        XCTAssertEqual(ProStore.productID, "com.naheeminnis.donenow.pro")
        XCTAssertEqual(ProStore.productIDs, [ProStore.productID])
        XCTAssertFalse(ProStore.productIDs.contains("local.aelo.donenow.pro"))
    }
}
