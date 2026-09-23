import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct FocusLayout {
    let size: CGSize
    let isPad: Bool
    var tablet: Bool { isPad && size.width >= 700 }
    var columns: Bool { tablet && size.width >= 1000 && size.width > size.height }
    var clockSize: CGFloat { min(tablet ? (columns ? 350 : 370) : 285, max(1, size.width - (tablet ? 64 : 40))) }
}

struct MainFocusView: View {
    @ScaledMetric(relativeTo: .body) private var themeCardHeight: CGFloat = 120
    @ScaledMetric(relativeTo: .body) private var themeCardWidth: CGFloat = 128
    @StateObject private var timer: TimerEngine
    init(timer: TimerEngine = TimerEngine(duration: 25 * 60)) {
        _timer = StateObject(wrappedValue: timer)
    }
    @StateObject private var audio = AudioPlayer()
    @StateObject private var store = ProStore()
    @EnvironmentObject private var ads: AdMobCoordinator
    @StateObject private var completionAlarm = CompletionAlarmPlayer()
    @StateObject private var completionNotifications = CompletionNotificationScheduler()
    @StateObject private var history = FocusHistoryStore.shared
    @AppStorage("developerProPreview") private var proUnlocked = false
    @AppStorage("selectedThemeName") private var selectedThemeName = Theme.analog.rawValue
    @AppStorage("completionHaptics") private var completionHaptics = true
    @AppStorage("completionSounds") private var completionSounds = true
    @AppStorage("autoPlayFocusAudio") private var autoPlayFocusAudio = true
    @AppStorage("autoPlayStopwatchAudio") private var autoPlayStopwatchAudio = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @AppStorage("focusSetupPromptSuppressed") private var focusSetupPromptSuppressed = false
    @State private var intention = ""
    @State private var customMinutes = 30.0
    @State private var showingDuration = false
    @State private var showingImporter = false
    @State private var showingCompletion = false
    @State private var showingProInfo = false
    @State private var showingSettings = false
    @State private var showingSoundscapePicker = false
    @State private var upgradeFromSoundscapePicker = false
    @State private var showingFocusSetup = false

    private var theme: Theme {
        let savedTheme = Theme(rawValue: selectedThemeName) ?? .analog
        if timer.isRunning && timer.mode == .stopwatch { return .stopwatch }
        if timer.isRunning && timer.mode == .countdown && savedTheme == .stopwatch { return .analog }
        // Never render a Pro-only clock without a verified entitlement. This
        // also handles refunds/revocations and stale persisted state.
        return savedTheme.isPro && !hasPro ? .analog : savedTheme
    }
    private var hasPro: Bool {
        #if DEBUG
        store.hasPro || proUnlocked
        #else
        store.hasPro
        #endif
    }
    private var progress: Double {
        guard timer.mode == .countdown else { return 0 }
        guard timer.selectedDuration > 0 else { return 0 }
        return min(1, max(0, 1 - timer.timeRemaining / timer.selectedDuration))
    }

    var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            GeometryReader { geometry in
                let layout = FocusLayout(size: geometry.size, isPad: UIDevice.current.userInterfaceIdiom == .pad)
                let tablet = layout.tablet
                let columns = layout.columns
                if !tablet {
                    ThemeBackdrop(theme: theme).ignoresSafeArea()
                }
                ScrollView {
                    VStack(spacing: tablet ? 32 : 24) {
                        header
                        intentionField
                        if columns {
                            HStack(alignment: .top, spacing: 40) {
                            timerPanel(clockSize: layout.clockSize)
                                    .frame(maxWidth: .infinity)
                                VStack(spacing: 28) {
                                    themeGallery
                                    musicCard
                                }
                                .frame(width: 380)
                            }
                        } else {
                            timerPanel(clockSize: layout.clockSize)
                            themeGallery
                            musicCard
                        }
                        Text("Your focus. Your rhythm. Your device.")
                            .font(.caption).foregroundStyle(.white.opacity(0.45)).padding(.bottom, 16)
                    }
                    .padding(.horizontal, tablet ? 32 : 20)
                    .padding(.top, tablet ? 28 : 14)
                    .frame(maxWidth: columns ? 1160 : (tablet ? 820 : 620))
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .foregroundStyle(.white).preferredColorScheme(.dark)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { audio.importAudio(from: url) }
        }
        .sheet(isPresented: $showingDuration) { customDurationSheet }
        .sheet(isPresented: $showingCompletion) { completionSheet }
        .sheet(isPresented: $showingProInfo) { proInfoSheet }
        .sheet(isPresented: $showingSettings) { SettingsView(store: store, history: history, developerProPreview: $proUnlocked, hasPro: hasPro) }
        .sheet(isPresented: $showingSoundscapePicker, onDismiss: {
            if upgradeFromSoundscapePicker {
                upgradeFromSoundscapePicker = false
                showingProInfo = true
            }
        }) {
            SoundscapePickerView(audio: audio, hasPro: hasPro) {
                upgradeFromSoundscapePicker = true
                showingSoundscapePicker = false
            }
        }
        .sheet(isPresented: $showingFocusSetup) { focusSetupSheet }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Keep the active focus session distraction-free and keep the banner
            // away from the frequently tapped timer controls.
            if !hasPro && !timer.isRunning {
                AdBannerSlot(consentReady: ads.canRequestAds, statusMessage: ads.statusMessage, retry: ads.retry) { showingProInfo = true }
                    .id(ads.consentRevision)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(theme.backgroundColor)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: timer.isFinished) { _, finished in
            if finished && timer.mode == .countdown {
                completionNotifications.cancel()
                history.record(duration: timer.selectedDuration, intention: intention, theme: theme)
                audio.pause()
                showingCompletion = true
                if completionSounds { completionAlarm.play(for: theme) }
                if completionHaptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            }
        }
        .onChange(of: timer.isRunning) { _, running in
            UIApplication.shared.isIdleTimerDisabled = running && keepScreenAwake
            if !running { syncTimerMode() }
        }
        .onChange(of: hasPro) { _, _ in reconcileEntitlement() }
        .onChange(of: store.entitlementLoaded) { _, _ in reconcileEntitlement() }
        .onChange(of: keepScreenAwake) { _, enabled in UIApplication.shared.isIdleTimerDisabled = timer.isRunning && enabled }
        .onAppear {
            syncTimerMode()
            #if DEBUG
            if CommandLine.arguments.contains("-previewCompletion") {
                showingCompletion = true
                if completionSounds { completionAlarm.play(for: theme) }
            }
            #endif
        }
        .onChange(of: selectedThemeName) { _, _ in syncTimerMode() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func timerPanel(clockSize: CGFloat) -> some View {
        VStack(spacing: 24) {
            ClockFaceView(theme: theme, progress: progress, time: timer.formatTime(timer.displayTime), isRunning: timer.isRunning, sessionElapsed: timer.sessionElapsed)
                .scaleEffect(clockSize / 285)
                .frame(width: clockSize, height: clockSize)
                .clipped()
                .frame(maxWidth: .infinity)
            if timer.mode == .countdown { durationBar }
            primaryControls
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("DoneNow").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("MAKE SPACE FOR WHAT MATTERS").font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(theme.accentColor)
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 18)).frame(width: 44, height: 44).background(.white.opacity(0.08), in: Circle())
            }.accessibilityLabel("Settings")
        }
    }

    private var intentionField: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope").font(.system(size: 20)).foregroundStyle(theme.accentColor)
            TextField("What are you focusing on?", text: $intention).submitLabel(.done)
        }
        .padding(15).background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.06)))
        .accessibilityElement(children: .contain)
    }

    private var durationBar: some View {
        VStack(spacing: 9) {
            HStack(spacing: 7) {
                ForEach([5, 15, 25, 45], id: \.self) { minutes in
                    durationButton(minutes)
                }
                Button { customMinutes = timer.selectedDuration / 60; showingDuration = true } label: {
                    Image(systemName: "slider.horizontal.3").frame(maxWidth: .infinity).padding(.vertical, 11)
                }
                .background(.white.opacity(0.06), in: Capsule())
                .disabled(timer.isRunning)
                .accessibilityLabel("Set a custom focus time")
            }
            if let message = completionNotifications.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "bell.slash").foregroundStyle(.orange)
                    Text(message).font(.caption).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button("Settings") {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accentColor)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func durationButton(_ minutes: Int) -> some View {
        let selected = Int(timer.selectedDuration / 60) == minutes
        return Button { timer.setDuration(Double(minutes * 60)) } label: {
            Text("\(minutes)m").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 11)
        }
        .foregroundStyle(selected ? theme.backgroundColor : .white.opacity(0.72))
        .background(selected ? theme.accentColor : .white.opacity(0.06), in: Capsule())
        .disabled(timer.isRunning).accessibilityLabel("\(minutes) minute focus session")
    }

    private var primaryControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button { toggleTimer() } label: {
                    Label(timer.isRunning ? "Pause" : (timer.mode == .stopwatch ? (timer.elapsedTime > 0 ? "Resume Stopwatch" : "Start Stopwatch") : "Start Focus"), systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
                }
                .foregroundStyle(theme.backgroundColor).background(theme.accentColor, in: RoundedRectangle(cornerRadius: 17)).disabled(timer.isFinished)
                Button { completionAlarm.stop(); completionNotifications.cancel(); SessionPlayback.reset(timer: timer, audio: audio, automaticMusic: automaticallyManageSessionMusic); showingCompletion = false } label: {
                    Image(systemName: "arrow.counterclockwise").font(.title3).frame(width: 56, height: 56)
                }
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 17)).accessibilityLabel("Reset focus timer")
            }
            if timer.mode == .stopwatch {
                Button("Finish and Save Session") { finishStopwatchSession() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accentColor)
                    .accessibilityLabel("Finish and save stopwatch session")
            }
        }
    }

    private var themeGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { sectionTitle("CLOCK FACES"); Spacer(); Text(hasPro ? "ALL 19 UNLOCKED" : "10 FREE · 9 PRO").font(.caption2.weight(.bold)).foregroundStyle(theme.accentColor) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Theme.allCases, id: \.self) { item in
                        themeButton(item)
                    }
                }.padding(.vertical, 2)
            }
            .frame(height: themeCardHeight)
            .clipped()
        }
    }

    private func themeButton(_ item: Theme) -> some View {
        let locked = item.isPro && !hasPro
        let selected = item == theme
        // Switching visual faces is safe while a session runs, but the
        // stopwatch is a different timer mode and must not reset or reinterpret
        // an active countdown (or vice versa).
        let modeConflict = timer.isRunning && ((item == .stopwatch) != (timer.mode == .stopwatch))
        return Button {
            if locked { showingProInfo = true } else { selectedThemeName = item.rawValue }
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Image(systemName: item.icon).font(.title2); Spacer(); if locked { Image(systemName: "lock.fill").font(.caption) } }
                Text(item.rawValue).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(item.atmosphere).font(.caption2).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            .frame(width: themeCardWidth, alignment: .leading).padding(14)
            .foregroundStyle(selected ? item.accentColor : .white.opacity(locked ? 0.5 : 0.82))
            .background(selected ? item.accentColor.opacity(0.12) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(selected ? item.accentColor.opacity(0.75) : .white.opacity(0.055)))
        }
        .disabled(modeConflict)
        .accessibilityLabel("\(item.rawValue) clock face\(locked ? ", Pro" : "")")
        .accessibilityHint(modeConflict ? "Pause the session before switching between countdown and stopwatch modes." : "")
    }

    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("FOCUS MUSIC")
                Spacer()
                if audio.selectedImportedTrack != nil {
                    Button("Remove Selected") { audio.removeImportedAudio() }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                        .accessibilityLabel("Remove selected custom music")
                }
                Button { showingImporter = true } label: {
                    Label("Add Music", systemImage: "plus")
                }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.accentColor)
            }
            Button { showingSoundscapePicker = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(audio.selectedImportedTrack?.title ?? audio.selectedSoundscape.title).font(.subheadline.weight(.semibold))
                        Text(audio.selectedImportedTrack != nil ? "Custom music · stored on this device" : (hasPro ? "11 soundscapes available" : "5 free · 6 Pro"))
                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.bold))
                }
                .padding(13)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
            }
            .tint(theme.accentColor)
            .accessibilityLabel("Focus music: \(audio.selectedImportedTrack?.title ?? audio.selectedSoundscape.title)")
            HStack(spacing: 14) {
                Button { audio.isPlaying ? audio.pause() : audio.play() } label: {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill").font(.title3).frame(width: 48, height: 48)
                        .background(theme.accentColor.opacity(audio.isAvailable ? 1 : 0.25), in: Circle()).foregroundStyle(theme.backgroundColor)
                }.disabled(!audio.isAvailable).accessibilityLabel(audio.isPlaying ? "Pause focus music" : "Play focus music")
                VStack(alignment: .leading, spacing: 4) {
                    Text(audio.trackName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(audio.isAvailable ? "Loops during your session" : "Add music from Files · stays on device").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button { audio.toggleMute() } label: { Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill").frame(width: 36, height: 44) }
                    .disabled(!audio.isAvailable).accessibilityLabel(audio.isMuted ? "Unmute focus music" : "Mute focus music")
            }
            Slider(value: Binding(get: { audio.volume }, set: { audio.setVolume($0) }), in: 0...1)
                .tint(theme.accentColor)
                .disabled(!audio.isAvailable)
                .accessibilityLabel("Focus music volume")
            if let error = audio.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
        }
        .padding(17).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.055)))
    }

    private var customDurationSheet: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 28) {
                Text("\(Int(customMinutes)) minutes").font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                Slider(value: $customMinutes, in: 1...180, step: 1).tint(theme.accentColor)
                HStack { Text("1 min"); Spacer(); Text("3 hours") }.font(.caption).foregroundStyle(.secondary)
                Button("Use This Time") { timer.setDuration(customMinutes * 60); showingDuration = false }
                    .buttonStyle(.borderedProminent).tint(theme.accentColor).foregroundStyle(theme.backgroundColor)
                    .disabled(timer.isRunning)
            }.padding(28)
            }.navigationTitle("Custom Focus Time").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingDuration = false } } }
        }.presentationDetents([.medium, .large])
    }

    private var completionSheet: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            if theme == .candle { FireworkCelebration(color: theme.accentColor) }
            ScrollView {
            VStack(spacing: 20) {
                Image(systemName: theme.icon).font(.system(size: 58)).foregroundStyle(theme.accentColor)
                Text(theme.completionMessage).font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(intention.isEmpty ? "You made space for what matters." : "You made space for \(intention).").multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.68))
                Label(theme.alarmName, systemImage: "speaker.wave.2.fill").font(.caption).foregroundStyle(theme.accentColor)
                Button("Start Another") { completionAlarm.stop(); showingCompletion = false; timer.reset(); startFocusSession() }.buttonStyle(.borderedProminent).tint(theme.accentColor).foregroundStyle(theme.backgroundColor)
                Button("Finish for now") { completionAlarm.stop(); completionNotifications.cancel(); showingCompletion = false; timer.reset() }.foregroundStyle(.white)
            }.padding(30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).presentationDetents([.medium, .large])
        .onDisappear { completionAlarm.stop() }
    }

    private var proInfoSheet: some View {
        ScrollView {
        VStack(spacing: 18) {
            Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(theme.accentColor)
            Text("More ways to focus").font(.title2.bold())
            Text("Pro adds six additional soundscapes, the Time Trial clock face, nine animated clock faces, removes ads, saves your focus history and streaks, and adds daily focus reminders. Everything stays on this device.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            #if DEBUG
            Button("Preview Pro") { proUnlocked = true; showingProInfo = false }.buttonStyle(.borderedProminent).tint(theme.accentColor)
            #else
            Button {
                Task { await store.purchase() }
            } label: {
                Text(store.isLoading ? "Checking Pro availability…" : store.product.map { "Buy Pro · \($0.displayPrice)" } ?? "Try Again")
            }
                .buttonStyle(.borderedProminent).tint(theme.accentColor).disabled(store.isLoading || store.isPurchasing)
            #endif
            Button("Restore Purchases") { Task { await store.restore() } }
                .disabled(store.isPurchasing)
            if let message = store.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Not now") { showingProInfo = false }
        }.padding(30)
        }.presentationDetents([.medium, .large])
    }

    private var focusSetupSheet: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(theme.accentColor)
                Text("Set Up Focus")
                    .font(.title2.bold())
                Text("DoneNow cannot turn Apple Focus on or off automatically. Before starting, open Control Center, choose a Focus, then return here.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("I’ve Enabled Focus — Start Timer") {
                    showingFocusSetup = false
                    startFocusSession()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accentColor)
                .foregroundStyle(theme.backgroundColor)
                Toggle("Don’t ask again", isOn: $focusSetupPromptSuppressed)
                    .font(.subheadline)
                Button("Not Now") { showingFocusSetup = false }
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            }
            .navigationTitle("Focus Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value).font(.system(size: 10, weight: .bold)).tracking(1.6).foregroundStyle(.white.opacity(0.52))
    }

    private var automaticallyManageSessionMusic: Bool {
        SessionMusicPreferences.shouldStart(mode: timer.mode, countdown: autoPlayFocusAudio, stopwatch: autoPlayStopwatchAudio)
    }

    private func toggleTimer() {
        if timer.isRunning {
            SessionPlayback.pause(timer: timer, audio: audio, automaticMusic: automaticallyManageSessionMusic)
            completionNotifications.cancel()
        } else if !focusSetupPromptSuppressed {
            showingFocusSetup = true
        } else {
            startFocusSession()
        }
    }

    private func startFocusSession() {
        SessionPlayback.start(timer: timer, audio: audio, automaticMusic: automaticallyManageSessionMusic)
        if timer.mode == .countdown {
            completionNotifications.schedule(after: timer.timeRemaining, intention: intention, message: theme.completionMessage)
        }
    }

    private func syncTimerMode() {
        guard !timer.isRunning else { return }
        timer.reconcileMode(wantsStopwatch: theme == .stopwatch && hasPro)
    }

    private func reconcileEntitlement() {
        syncTimerMode()
        audio.reconcileEntitlement(hasPro: hasPro, resolved: store.entitlementLoaded)
    }


    private func finishStopwatchSession() {
        guard timer.mode == .stopwatch else { return }
        timer.pause()
        guard timer.elapsedTime >= 1 else {
            timer.reset()
            return
        }
        history.record(duration: timer.elapsedTime, intention: intention, theme: theme)
        audio.pause()
        timer.reset()
    }
}

struct ClockFaceView: View {
    let theme: Theme
    let progress: Double
    let time: String
    let isRunning: Bool
    var sessionElapsed: TimeInterval = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = ClockMotion()
    private var amount: Double { ClockGeometry.clamp(progress) }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isRunning || reduceMotion)) { context in
            let phase = reduceMotion ? 0 : motion.phase(at: context.date)
            ZStack {
                face(phase: phase)
                progressOverlay
                centerContent
            }
        }
        .frame(width: 285, height: 285)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: theme)
        .onAppear { motion.setRunning(isRunning, at: Date()) }
        .onChange(of: isRunning) { _, running in motion.setRunning(running, at: Date()) }
        .onChange(of: progress) { old, new in
            if new == 0 && old > 0 { motion.reset(running: isRunning, at: Date()) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.rawValue + (theme == .stopwatch ? ", elapsed time" : ", time remaining"))
        .accessibilityValue(time)
    }
    private var clockFont: Font {
        switch theme {
        case .digital, .stopwatch: return .system(size: 55, weight: .bold, design: .monospaced)
        case .cuckoo, .grandfather: return .system(size: 44, weight: .semibold, design: .serif)
        case .steampunk: return .system(size: 55, weight: .semibold, design: .serif)
        default: return .system(size: 55, weight: .light, design: .rounded)
        }
    }
    @ViewBuilder private var centerContent: some View {
        switch theme {
        case .flip:
            HStack(alignment: .center, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(Array(minutesText.enumerated()), id: \.offset) { _, character in
                        flipDigit(String(character), large: true)
                    }
                }

                Text(":")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .frame(width: 13)

                HStack(spacing: 4) {
                    ForEach(Array(secondsText.enumerated()), id: \.offset) { _, character in
                        flipDigit(String(character), large: true)
                    }
                }
            }
            .scaleEffect(minutesText.count > 2 ? 0.86 : 1)
        case .word:
            VStack(spacing: 8) {
                Text(numberWords(minutes)).font(.system(size: 28, weight: .black, design: .rounded))
                Text(minutes == 1 ? "MINUTE" : "MINUTES").font(.caption.bold()).tracking(3)
                Text("\(seconds) \(seconds == 1 ? "SECOND" : "SECONDS")").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(theme.accentColor.opacity(0.7))
            }.multilineTextAlignment(.center).padding(30)
        case .binary:
            BinaryTimeView(time: time, color: theme.accentColor)
        case .railway:
            VStack(spacing: 7) {
                Text(time).font(.system(size: 45, weight: .black, design: .rounded)).monospacedDigit().foregroundStyle(.black)
                Text(isRunning ? "NEXT STOP: DONE" : "PLATFORM PRECISION").font(.system(size: 8, weight: .black)).tracking(1.3).foregroundStyle(.red)
            }
            .shadow(color: .white, radius: 3)
        case .grandfather, .cuckoo:
            Text(time).font(.system(size: minutesText.count > 2 ? 28 : 34, weight: .semibold, design: .serif))
                .monospacedDigit().padding(.horizontal, 5).padding(.vertical, 3)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                .offset(y: theme == .grandfather ? -48 : 28)
        case .candle:
            VStack(spacing: 7) {
                Text(time).font(.system(size: 43, weight: .light, design: .rounded)).monospacedDigit()
                Text(isRunning ? "KEEP THE FLAME" : theme.atmosphere.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(theme.accentColor)
            }.offset(y: -103)
        case .hourglass:
            ZStack {
                Text(time).font(clockFont).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    .shadow(color: theme.backgroundColor, radius: 3)
                Text(isRunning ? "STAY WITH IT" : theme.atmosphere.uppercased())
                    .font(.system(size: 9, weight: .bold)).tracking(1.5)
                    .foregroundStyle(theme.accentColor).offset(y: 116)
            }
        case .stopwatch:
            VStack(spacing: 8) {
                Text(time).font(clockFont).monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
                Text(ClockGeometry.stopwatchStatus(time: time, running: isRunning)).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2.5).foregroundStyle(theme.accentColor)
            }
            .frame(maxWidth: 200)
            .padding(.horizontal, 22).padding(.vertical, 18)
            .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.accentColor.opacity(0.5), lineWidth: 2))
        default:
            VStack(spacing: 7) {
                if theme != .world && theme != .hourglass {
                    Image(systemName: theme.icon).foregroundStyle(theme.accentColor).font(.system(size: 20))
                }
                Text(time).font(clockFont).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    .shadow(color: theme.backgroundColor, radius: 3)
                    .accessibilityLabel("Time remaining").accessibilityValue(time)
                Text(isRunning ? "STAY WITH IT" : theme.atmosphere.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(theme.accentColor.opacity(0.8))
            }
        }
    }

    private var minutes: Int { Int(time.split(separator: ":").first ?? "0") ?? 0 }
    private var seconds: Int { Int(time.split(separator: ":").last ?? "0") ?? 0 }
    private var minutesText: String { String(format: "%02d", minutes) }
    private var secondsText: String { String(format: "%02d", seconds) }

    private func flipDigit(_ value: String, large: Bool) -> some View {
        FlipDigitCard(value: value, large: large)
    }

    private func numberWords(_ number: Int) -> String {
        let small = ["ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN", "TWELVE", "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN", "SEVENTEEN", "EIGHTEEN", "NINETEEN"]
        let tens = ["", "", "TWENTY", "THIRTY", "FORTY", "FIFTY", "SIXTY", "SEVENTY", "EIGHTY", "NINETY"]
        if number < 20 { return small[max(0, number)] }
        if number < 100 { return tens[number / 10] + (number % 10 == 0 ? "" : " " + small[number % 10]) }
        let remainder = number % 100
        if number >= 1000 { return String(number) }
        return small[number / 100] + " HUNDRED" + (remainder == 0 ? "" : " " + numberWords(remainder))
    }
    @ViewBuilder private func face(phase: TimeInterval) -> some View {
        switch theme {
        case .steampunk:
            ZStack { Circle().fill(.black.opacity(0.22)); ForEach(0..<24) { i in Capsule().fill(theme.accentColor.opacity(i % 3 == 0 ? 0.8 : 0.25)).frame(width: 2, height: i % 3 == 0 ? 15 : 7).offset(y: -125).rotationEffect(.degrees(Double(i) * 15 + phase * 8)) }; Circle().stroke(theme.accentColor.opacity(0.28), lineWidth: 2).padding(24) }
        case .digital:
            RoundedRectangle(cornerRadius: 28).fill(.black.opacity(0.42)).overlay { GeometryReader { proxy in Rectangle().fill(theme.accentColor.opacity(0.16)).frame(height: 2).offset(y: (sin(phase * 1.7) * 0.5 + 0.5) * proxy.size.height).blur(radius: 1) } }.overlay(RoundedRectangle(cornerRadius: 28).stroke(theme.accentColor.opacity(0.3), lineWidth: 1)).padding(12)
        case .analog:
            ZStack {
                Circle().fill(.black.opacity(0.25)).overlay(Circle().stroke(theme.accentColor.opacity(0.45), lineWidth: 2)).padding(8)
                ForEach(0..<12) { i in Capsule().fill(theme.accentColor.opacity(i % 3 == 0 ? 0.85 : 0.38)).frame(width: 2, height: i % 3 == 0 ? 13 : 7).offset(y: -124).rotationEffect(.degrees(Double(i) * 30)) }
                Capsule().fill(theme.accentColor).frame(width: 4, height: 75).offset(y: -35).rotationEffect(.degrees(amount * 360))
                Capsule().fill(.white.opacity(0.8)).frame(width: 2, height: 54).offset(y: -25).rotationEffect(.degrees(amount * 30))
                Circle().fill(theme.accentColor).frame(width: 12)
            }
        case .hourglass:
            HourglassFace(progress: amount, phase: phase, color: theme.accentColor, isRunning: isRunning && !reduceMotion)
        case .flip:
            RoundedRectangle(cornerRadius: 28)
                .fill(.white.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(theme.accentColor.opacity(0.25), lineWidth: 2))
                .padding(8)
        case .word:
            RoundedRectangle(cornerRadius: 42)
                .fill(.white.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: 42)
                        .stroke(.white.opacity(0.10 + (sin(phase * 1.2) + 1) * 0.03), lineWidth: 1)
                }
                .padding(6)
        case .railway:
            ZStack {
                Circle().fill(.white.opacity(0.92)).overlay(Circle().stroke(.black.opacity(0.75), lineWidth: 5)).padding(8)
                ForEach(0..<60) { i in Capsule().fill(.black.opacity(i % 5 == 0 ? 0.9 : 0.45)).frame(width: i % 5 == 0 ? 3 : 1, height: i % 5 == 0 ? 18 : 8).offset(y: -124).rotationEffect(.degrees(Double(i) * 6)) }
                Capsule().fill(.black).frame(width: 5, height: 78).offset(y: -34).rotationEffect(.degrees(amount * 360))
                Capsule().fill(.red).frame(width: 2, height: 105).offset(y: -47).rotationEffect(.degrees(amount * 720))
                Capsule().fill(theme.accentColor).frame(width: 2, height: 92).offset(y: -43)
                    .rotationEffect(.degrees(ClockGeometry.chronographTurns(elapsed: sessionElapsed, period: 60) * 360))
                Circle().fill(.red).frame(width: 13)
            }
        case .water:
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 45).fill(.white.opacity(0.04)).frame(width: 175, height: 230)
                ZStack(alignment: .bottom) {
                    Rectangle().fill(LinearGradient(colors: [.cyan.opacity(0.85), .blue.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                        .overlay { WaveLines(phase: phase, color: theme.accentColor) }
                        .frame(width: 165, height: 215 * (1 - amount)).clipped()
                }
                .frame(width: 165, height: 215, alignment: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 39))
                .padding(.bottom, 7)
                RoundedRectangle(cornerRadius: 45).stroke(theme.accentColor.opacity(0.75), lineWidth: 3).frame(width: 175, height: 230)
            }
        case .zen:
            ZStack {
                Circle().fill(.white.opacity(0.035))
                ForEach(0..<7) { i in
                    Capsule()
                        .fill(theme.accentColor.opacity(0.15 + (sin(phase * 0.7 + Double(i)) + 1) * 0.025))
                        .frame(width: CGFloat(80 + i * 24), height: 2)
                        .offset(y: CGFloat(i * 9 - 27))
                        .rotationEffect(.degrees(sin(phase * 0.35 + Double(i)) * 1.5))
                }
            }
        case .cosmos:
            ZStack { Circle().fill(.black.opacity(0.3)); ForEach(0..<3) { i in Ellipse().stroke(theme.accentColor.opacity(0.25), lineWidth: 1).frame(width: CGFloat(145 + i * 40), height: CGFloat(85 + i * 55)).rotationEffect(.degrees(Double(i * 52) + phase * Double(4 + i * 2))) }; Image(systemName: "sparkles").font(.system(size: 180)).opacity(0.08) }
        case .solar:
            ZStack {
                Circle().fill(RadialGradient(colors: [theme.accentColor.opacity(0.28), .orange.opacity(0.08), .clear], center: .center, startRadius: 15, endRadius: 140))
                ForEach(0..<20) { i in
                    Capsule().fill(theme.accentColor.opacity(0.24 + (sin(phase * 0.5 + Double(i)) + 1) * 0.03))
                        .frame(width: 2, height: 16)
                        .offset(y: -128)
                        .rotationEffect(.degrees(Double(i) * 18 + phase * 0.6))
                }
            }
        case .grandfather:
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Color(red: 0.20, green: 0.09, blue: 0.035))
                    .frame(width: 205, height: 274)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(theme.accentColor.opacity(0.4), lineWidth: 3))
                MechanicalDial(progress: amount, color: theme.accentColor, diameter: 150)
                    .offset(y: -48)
                PendulumAssembly(length: 64, color: theme.accentColor, angle: sin(phase * 2.4) * 10)
                    .offset(y: 70)
                ForEach([-1.0, 1.0], id: \.self) { side in
                    VStack(spacing: 0) {
                        Rectangle().fill(theme.accentColor.opacity(0.45)).frame(width: 1.5, height: 28 + amount * 20)
                        Capsule().fill(theme.accentColor.opacity(0.75)).frame(width: 12, height: 22)
                    }
                    .frame(height: 70, alignment: .top).offset(x: side * 58, y: 67)
                }
            }
        case .cuckoo:
            ZStack {
                CuckooHouse().fill(Color(red: 0.22, green: 0.12, blue: 0.035))
                    .overlay(CuckooHouse().stroke(theme.accentColor.opacity(0.5), lineWidth: 3))
                    .frame(width: 240, height: 265)
                // The aperture stays attached to the house. Only the bird emerges.
                let reveal = ClockGeometry.birdReveal(amount)
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.72))
                    Image(systemName: "bird.fill").font(.system(size: 29))
                        .foregroundStyle(theme.accentColor)
                        .scaleEffect(0.55 + reveal * 0.45)
                        .offset(x: (1 - reveal) * -28)
                        .opacity(reveal)
                }
                .frame(width: 66, height: 42).clipped().offset(y: -65)
                MechanicalDial(progress: amount, color: theme.accentColor, diameter: 122)
                    .offset(y: 28)
                PendulumAssembly(length: 20, color: theme.accentColor, angle: sin(phase * 2.4) * 7)
                    .scaleEffect(0.7).offset(y: 105)
            }
        case .aurora:
            Circle().fill(AngularGradient(colors: [.cyan.opacity(0.28), .purple.opacity(0.3), .mint.opacity(0.26), .cyan.opacity(0.28)], center: .center)).rotationEffect(.degrees(phase * 3)).overlay(Circle().fill(.black.opacity(0.45)).padding(18))
        case .binary:
            RoundedRectangle(cornerRadius: 28)
                .fill(.black.opacity(0.4))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(theme.accentColor.opacity(0.25 + (sin(phase * 2) + 1) * 0.05), lineWidth: 2)
                }
                .padding(10)
        case .chronograph:
            ZStack {
                Circle().fill(.black.opacity(0.36)).overlay(Circle().stroke(theme.accentColor.opacity(0.55), lineWidth: 3)).padding(5)
                ForEach(0..<60) { i in Capsule().fill(.white.opacity(i % 5 == 0 ? 0.7 : 0.2)).frame(width: 1.5, height: i % 5 == 0 ? 14 : 6).offset(y: -126).rotationEffect(.degrees(Double(i) * 6)) }
                ChronographSubdial(label: "MIN", fraction: ClockGeometry.chronographTurns(elapsed: sessionElapsed, period: 3600), color: theme.accentColor).offset(x: -62, y: 78)
                ChronographSubdial(label: "SEC", fraction: ClockGeometry.chronographTurns(elapsed: sessionElapsed, period: 60), color: theme.accentColor).offset(x: 62, y: 78)
                Capsule().fill(theme.accentColor).frame(width: 2, height: 92).offset(y: -42)
                    .rotationEffect(.degrees(ClockGeometry.chronographTurns(elapsed: sessionElapsed, period: 60) * 360))
                Circle().fill(theme.accentColor).frame(width: 9)
            }
        case .world:
            ZStack {
                Circle().fill(.blue.opacity(0.12)).padding(6)
                Circle().stroke(theme.accentColor.opacity(0.35), lineWidth: 1).padding(22)
                let orbit = ClockGeometry.orbit(amount)
                Image(systemName: "globe.americas.fill").font(.system(size: 30))
                    .foregroundStyle(.cyan)
                    .background(Circle().fill(theme.backgroundColor).padding(-3))
                    .offset(x: orbit.x, y: orbit.y)
            }
        case .candle:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if amount < 1 {
                    Image(systemName: "flame.fill").font(.system(size: 32))
                        .foregroundStyle(.yellow)
                        .shadow(color: .orange, radius: 8 + CGFloat((sin(phase * 7) + 1) * 2))
                }
                RoundedRectangle(cornerRadius: 7)
                    .fill(LinearGradient(colors: [.orange.opacity(0.95), .red.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 76, height: 130 * (1 - amount))
                Capsule().fill(theme.accentColor.opacity(0.4)).frame(width: 104, height: 5)
            }.frame(height: 185).offset(y: 35)
        case .stopwatch:
            RoundedRectangle(cornerRadius: 28)
                .fill(.black.opacity(0.42))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(theme.accentColor.opacity(0.65), lineWidth: 3))
                .overlay(alignment: .top) {
                    HStack(spacing: 8) {
                        Circle().fill(theme.accentColor).frame(width: 7, height: 7)
                        Text("STOPWATCH").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(2)
                    }
                    .foregroundStyle(theme.accentColor)
                    .padding(.top, 28)
                }
                .padding(9)
        }
    }

    @ViewBuilder private var progressOverlay: some View {
        switch theme {
        case .digital, .flip, .binary, .stopwatch:
            RoundedRectangle(cornerRadius: 28).trim(from: 0, to: amount).stroke(theme.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round)).padding(theme == .binary ? 10 : (theme == .flip ? 8 : 12))
        case .word:
            RoundedRectangle(cornerRadius: 42).trim(from: 0, to: amount).stroke(theme.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round)).padding(6)
        case .grandfather, .cuckoo:
            ZStack(alignment: .bottom) {
                Capsule().fill(theme.accentColor.opacity(0.18)).frame(width: 6, height: 190)
                Capsule().fill(theme.accentColor).frame(width: 6, height: 190 * amount)
            }.offset(x: 130)
        case .hourglass, .water, .candle:
            EmptyView()
        default:
            Circle().trim(from: 0, to: amount).stroke(theme.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90)).padding(3)
        }
    }
}

private struct FlipDigitCard: View {
    let value: String
    let large: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var state: FlipDigitState

    init(value: String, large: Bool) {
        self.value = value
        self.large = large
        _state = StateObject(wrappedValue: FlipDigitState(value))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: large ? 12 : 9).fill(.black.opacity(0.48))
            Text(state.displayedValue)
                .font(.system(size: large ? 45 : 30, weight: .black, design: .rounded)).monospacedDigit()
            Rectangle().fill(.white.opacity(0.16)).frame(height: 1)
        }
        .frame(width: large ? 49 : 31, height: large ? 88 : 60)
        .rotation3DEffect(.degrees(state.angle), axis: (x: 1, y: 0, z: 0), perspective: 0.72)
        .onChange(of: value, initial: true) { _, next in state.update(next, animated: !reduceMotion) }
        .onChange(of: reduceMotion) { _, _ in state.update(value, animated: false) }
        .onDisappear { state.update(value, animated: false) }
    }
}

private struct HourglassHalf: Shape {
    let inverted: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if inverted {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        path.closeSubpath(); return path
    }
}

private struct HourglassFace: View {
    let progress: Double
    let phase: TimeInterval
    let color: Color
    let isRunning: Bool

    var body: some View {
        let geometry = HourglassGeometry(progress: progress)
        ZStack {
            // A fixed triangular chamber masked from its top downward.
            HourglassHalf(inverted: false).fill(color.opacity(0.82))
                .frame(width: 150, height: 88)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: geometry.upperHeight)
                }.offset(y: -46)
            HourglassHalf(inverted: true).fill(color.opacity(0.82))
                .frame(width: 150, height: geometry.lowerHeight)
                .offset(y: geometry.lowerCenter)
            if isRunning && progress < 1 {
                ForEach(0..<14, id: \.self) { index in
                    let travel = (phase * 1.4 + Double(index) / 14).truncatingRemainder(dividingBy: 1)
                    Circle().fill(color.opacity(0.88)).frame(width: 2.2, height: 2.2)
                        .offset(x: sin(Double(index) * 7) * 1.4,
                                y: -2 + travel * (geometry.lowerApex + 2))
                }
            }
            HourglassHalf(inverted: false).stroke(color.opacity(0.78), lineWidth: 3)
                .frame(width: 165, height: 96).offset(y: -51)
            HourglassHalf(inverted: true).stroke(color.opacity(0.78), lineWidth: 3)
                .frame(width: 165, height: 96).offset(y: 51)
        }
    }
}

private struct WaveLines: View {
    let phase: TimeInterval
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(color.opacity(0.22))
                    .frame(width: 110 - CGFloat(index * 10), height: 2)
                    .offset(x: CGFloat(sin(phase * 1.8 + Double(index)) * 14))
            }
        }
        .padding(.bottom, 22)
    }
}

private struct CuckooHouse: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); path.move(to: CGPoint(x: rect.midX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.34)); path.addLine(to: CGPoint(x: rect.width * 0.88, y: rect.height * 0.34)); path.addLine(to: CGPoint(x: rect.width * 0.88, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.width * 0.12, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.width * 0.12, y: rect.height * 0.34)); path.addLine(to: CGPoint(x: rect.minX, y: rect.height * 0.34)); path.closeSubpath(); return path
    }
}

private struct BinaryTimeView: View {
    let time: String
    let color: Color
    private var digits: [Int] { time.compactMap { $0.wholeNumberValue } }

    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 14) {
                ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                    VStack(spacing: 8) {
                        ForEach((0..<4).reversed(), id: \.self) { bit in
                            Circle().fill((digit & (1 << bit)) != 0 ? color : color.opacity(0.12)).frame(width: 17, height: 17)
                        }
                    }
                }
            }
            Text(time).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(color.opacity(0.8))
        }.accessibilityElement(children: .ignore).accessibilityLabel("Time remaining").accessibilityValue(time)
    }
}

private struct FireworkCelebration: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        ZStack {
            ForEach(0..<36, id: \.self) { index in
                let angle = Double(index) * 10 * Double.pi / 180
                let radius = CGFloat(70 + (index % 3) * 34)
                Circle()
                    .fill(index.isMultiple(of: 3) ? color : (index.isMultiple(of: 2) ? Color.yellow : Color.pink))
                    .frame(width: index.isMultiple(of: 4) ? 9 : 5, height: index.isMultiple(of: 4) ? 9 : 5)
                    .offset(x: expanded ? cos(angle) * radius : 0, y: expanded ? sin(angle) * radius : 0)
                    .opacity(expanded ? 0.18 : 0.95)
            }
        }
        .onAppear {
            if reduceMotion { expanded = true }
            else { withAnimation(.easeOut(duration: 1.4)) { expanded = true } }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
