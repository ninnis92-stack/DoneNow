import AVFoundation
import SwiftUI

@MainActor
final class AudioPlayer: ObservableObject {
    enum BuiltInSoundscape: String, CaseIterable, Identifiable {
        case atmosphere
        case thunderstorm
        case rain
        case ocean
        case fireplace
        case forest
        case stream
        case softWind
        case morningBirds
        case deepSpace
        case rainDelay

        var id: String { rawValue }

        /// The free tier keeps the core focus experience useful with five
        /// distinct, broadly appealing soundscapes. The remaining presets
        /// are additive Pro content; playback itself is never disabled.
        var isPro: Bool {
            switch self {
            case .atmosphere, .ocean, .fireplace, .forest, .stream:
                return false
            case .thunderstorm, .rain, .softWind, .morningBirds, .deepSpace, .rainDelay:
                return true
            }
        }

        var ordinal: Int {
            switch self {
            case .atmosphere: return 1
            case .thunderstorm: return 2
            case .rain: return 3
            case .ocean: return 4
            case .fireplace: return 5
            case .forest: return 6
            case .stream: return 7
            case .softWind: return 8
            case .morningBirds: return 9
            case .deepSpace: return 10
            case .rainDelay: return 11
            }
        }

        var title: String {
            switch self {
            case .atmosphere: return "Timekeeper"
            case .thunderstorm: return "Thunderstorm"
            case .rain: return "Gentle Rain"
            case .ocean: return "Calm Ocean"
            case .fireplace: return "Fireplace"
            case .forest: return "Forest"
            case .stream: return "Quiet Stream"
            case .softWind: return "Soft Wind"
            case .morningBirds: return "Morning Birds"
            case .deepSpace: return "Deep Space"
            case .rainDelay: return "Rainfall Reverie"
            }
        }

        var bundledResourceName: String {
            switch self {
            case .atmosphere: return "focus_atmosphere"
            case .thunderstorm: return "thunderstorm"
            case .rain: return "gentle_rain"
            case .ocean: return "calm_ocean"
            case .fireplace: return "fireplace"
            case .forest: return "forest"
            case .stream: return "stream"
            case .softWind: return "soft_wind"
            case .morningBirds: return "morning_birds"
            case .deepSpace: return "deep_space"
            case .rainDelay: return "atmosphere"
            }
        }
    }

    struct ImportedTrack: Identifiable, Codable, Equatable {
        let id: UUID
        let title: String
        let fileName: String

        var idValue: UUID { id }
    }

    @Published var isPlaying: Bool = false
    @Published var volume: Float = 1.0
    @Published var isMuted: Bool = false
    @Published var isAvailable: Bool = false
    @Published var trackName: String = "No focus music selected"
    @Published var errorMessage: String?
    @Published private(set) var selectedSoundscape: BuiltInSoundscape = .atmosphere
    @Published private(set) var hasImportedAudio = false
    @Published private(set) var importedTracks: [ImportedTrack] = []
    @Published private(set) var selectedImportedTrackID: UUID?

    var selectedImportedTrack: ImportedTrack? {
        importedTracks.first { $0.id == selectedImportedTrackID }
    }
    
    private var player: AVAudioPlayer?
    private let importedTrackNameKey = "importedFocusTrackName"
    private let importedTracksKey = "importedFocusTracks"
    private let selectedImportedTrackKey = "selectedImportedFocusTrackID"
    private let useImportedAudioKey = "useImportedFocusAudio"
    private let soundscapeKey = "selectedBuiltInSoundscape"
    private var resumeAfterInterruption = false
    private var premiumAccess: Bool? = nil
    private var audioObservers: [NSObjectProtocol] = []
    
    init() {
        configureAudioSession()
        loadSound()
        registerAudioNotifications()
    }

    deinit {
        audioObservers.forEach(NotificationCenter.default.removeObserver)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Keep the initial category conservative. Optional route flags can
            // produce AVAudioSession parameter errors on some device/route
            // combinations; playback, mixing, AirPlay, and Bluetooth output
            // remain available through the system route without requiring them
            // during initial activation.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            errorMessage = "Focus audio is unavailable on this device (\(error.localizedDescription))."
        }
    }

    private func activateAudioSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            return true
        } catch {
            // Retry without mixing. This handles routes that reject the
            // combination while another app or accessory owns the session.
            do {
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true, options: [])
                return true
            } catch {
                errorMessage = "Focus audio could not activate: \(error.localizedDescription)"
                return false
            }
        }
    }

    private func registerAudioNotifications() {
        let center = NotificationCenter.default
        audioObservers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] notification in
            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
                self.handleInterruption(began: type == .began, shouldResume: options.contains(.shouldResume))
            }
        })
        audioObservers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] notification in
            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            Task { @MainActor [weak self] in
                guard let self, reason == .oldDeviceUnavailable, self.isPlaying else { return }
                self.pause()
                self.errorMessage = "Focus music paused because the audio route changed."
            }
        })
    }

    func handleInterruption(began: Bool, shouldResume: Bool) {
        if began {
            resumeAfterInterruption = isPlaying
            player?.pause()
            isPlaying = false
        } else {
            let resume = resumeAfterInterruption && shouldResume
            resumeAfterInterruption = false
            if resume { play() }
        }
    }

    func reconcileEntitlement(hasPro: Bool, resolved: Bool) {
        guard resolved else { return }
        premiumAccess = hasPro
        if !hasPro && selectedImportedTrackID == nil && selectedSoundscape.isPro {
            selectBuiltInSoundscape(.atmosphere)
        }
    }
    
    private func loadSound() {
        importedTracks = loadImportedTracks()
        selectedImportedTrackID = UserDefaults.standard.string(forKey: selectedImportedTrackKey).flatMap(UUID.init(uuidString:))
        if selectedImportedTrackID == nil,
           UserDefaults.standard.bool(forKey: useImportedAudioKey),
           let firstImportedTrack = importedTracks.first {
            selectedImportedTrackID = firstImportedTrack.id
            UserDefaults.standard.set(firstImportedTrack.id.uuidString, forKey: selectedImportedTrackKey)
        }
        let shouldUseImported = UserDefaults.standard.object(forKey: useImportedAudioKey) as? Bool ?? true
        let importedURL = selectedImportedTrack.flatMap { importedURL(for: $0) }
        if shouldUseImported,
           let importedURL,
           let importedPlayer = try? AVAudioPlayer(contentsOf: importedURL) {
            player = importedPlayer
            player?.numberOfLoops = -1
            player?.volume = isMuted ? 0 : volume
            player?.prepareToPlay()
            isAvailable = true
            hasImportedAudio = true
            trackName = selectedImportedTrack?.title ?? UserDefaults.standard.string(forKey: importedTrackNameKey) ?? "Imported focus music"
            return
        }
        do {
            // Prefer a distinct licensed field recording for every preset.
            // Procedural generation remains a safe fallback if a resource is
            // unavailable in a development build or after an interrupted update.
            let saved = UserDefaults.standard.string(forKey: soundscapeKey).flatMap(BuiltInSoundscape.init(rawValue:)) ?? .atmosphere
            let allowed = premiumAccess == false && saved.isPro ? BuiltInSoundscape.atmosphere : saved
            player = try Self.makePlayer(for: allowed)
            selectedSoundscape = allowed
            selectedImportedTrackID = nil
            UserDefaults.standard.removeObject(forKey: selectedImportedTrackKey)
            UserDefaults.standard.set(false, forKey: useImportedAudioKey)
            trackName = allowed.title
            hasImportedAudio = !importedTracks.isEmpty
            player?.numberOfLoops = -1 // Loop indefinitely
            player?.volume = isMuted ? 0 : volume
            isAvailable = true
            player?.prepareToPlay()
        } catch {
            isAvailable = false
            errorMessage = "Built-in focus audio could not be prepared."
        }
    }

    func selectBuiltInSoundscape(_ soundscape: BuiltInSoundscape) {
        guard premiumAccess != false || !soundscape.isPro else {
            errorMessage = "This soundscape requires Pro."
            return
        }
        do {
            let continuePlaying = isPlaying
            let replacement = try Self.makePlayer(for: soundscape)
            replacement.numberOfLoops = -1
            replacement.volume = isMuted ? 0 : volume
            replacement.prepareToPlay()
            player?.stop()
            player = replacement
            player?.numberOfLoops = -1
            player?.volume = isMuted ? 0 : volume
            player?.prepareToPlay()
            selectedSoundscape = soundscape
            trackName = soundscape.title
            selectedImportedTrackID = nil
            hasImportedAudio = !importedTracks.isEmpty
            UserDefaults.standard.set(soundscape.rawValue, forKey: soundscapeKey)
            isAvailable = true
            isPlaying = false
            errorMessage = nil
            UserDefaults.standard.set(false, forKey: useImportedAudioKey)
            UserDefaults.standard.removeObject(forKey: selectedImportedTrackKey)
            if continuePlaying { play() }
        } catch {
            errorMessage = "This focus sound could not be prepared. Your current audio was kept."
        }
    }

    private static func makePlayer(for soundscape: BuiltInSoundscape) throws -> AVAudioPlayer {
        if let url = Bundle.main.url(forResource: soundscape.bundledResourceName, withExtension: "mp3"),
           let recording = try? AVAudioPlayer(contentsOf: url) {
            recording.numberOfLoops = -1
            return recording
        }
        let fallback = try AVAudioPlayer(data: makeBuiltInSoundscape(soundscape))
        fallback.numberOfLoops = -1
        return fallback
    }

    private static func makeBuiltInSoundscape(_ soundscape: BuiltInSoundscape) throws -> Data {
        // Keep startup light: the loop is long enough to feel natural while
        // the contiguous sample buffer avoids thousands of tiny Data writes.
        let sampleRate = 16_000
        // A longer loop prevents the ear from locking onto a short repeating
        // pattern. Each recipe also adds irregular, deterministic events below
        // so the sound evolves while remaining reproducible for testing.
        let seconds = 24
        let channels = 2
        let frameCount = sampleRate * seconds
        var samples = [Int16](repeating: 0, count: frameCount * channels)
        var randomState: UInt32 = 0x1234ABCD ^ UInt32(soundscape.ordinal * 7919)
        var lowNoise = (left: 0.0, right: 0.0)
        var midNoise = (left: 0.0, right: 0.0)
        var crackleEnergy = 0.0
        var dropEnergy = 0.0
        var bubbleEnergy = 0.0
        var birdEnergy = 0.0

        func nextNoise() -> Double {
            randomState = 1664525 &* randomState &+ 1013904223
            return (Double(randomState) / Double(UInt32.max)) * 2 - 1
        }

        for frame in 0..<frameCount {
            let time = Double(frame) / Double(sampleRate)
            let loopFade = min(1, min(time / 0.35, (Double(seconds) - time) / 0.35))
            let leftWhite = nextNoise()
            let rightWhite = nextNoise()
            lowNoise.left = lowNoise.left * 0.992 + leftWhite * 0.008
            lowNoise.right = lowNoise.right * 0.992 + rightWhite * 0.008
            midNoise.left = midNoise.left * 0.82 + leftWhite * 0.18
            midNoise.right = midNoise.right * 0.82 + rightWhite * 0.18
            crackleEnergy *= 0.9985
            dropEnergy *= 0.992
            bubbleEnergy *= 0.994
            birdEnergy *= 0.999
            if nextNoise() > 0.997 { crackleEnergy = 0.45 + abs(nextNoise()) * 0.5 }
            if nextNoise() > 0.994 { dropEnergy = 0.35 + abs(nextNoise()) * 0.45 }
            if nextNoise() > 0.996 { bubbleEnergy = 0.22 + abs(nextNoise()) * 0.35 }
            if nextNoise() > 0.999 { birdEnergy = 0.25 + abs(nextNoise()) * 0.35 }
            let slow = 2 * Double.pi
            var left = 0.0
            var right = 0.0

            switch soundscape {
            case .atmosphere, .rainDelay:
                let breath = 0.55 + 0.45 * sin(slow * time / 12)
                let shimmer = sin(slow * 523.25 * time) * 0.035 + sin(slow * 659.25 * time + 0.4) * 0.025
                left = (sin(slow * 174.61 * time) * 0.20 + sin(slow * 261.63 * time + 0.4) * 0.13 + shimmer) * breath + lowNoise.left * 0.018
                right = (sin(slow * 174.61 * time + 0.7) * 0.20 + sin(slow * 329.63 * time) * 0.12 + shimmer * 0.8) * breath + lowNoise.right * 0.018
            case .thunderstorm:
                let rumble = sin(slow * 42 * time) * 0.11 + lowNoise.left * 0.24
                left = rumble + crackleEnergy * 0.08
                right = sin(slow * 42 * time + 0.5) * 0.10 + lowNoise.right * 0.24 + crackleEnergy * 0.06
            case .rain:
                let rainBed = midNoise.left * 0.17
                let dropTone = sin(slow * (1_750 + 180 * sin(slow * time / 2.3)) * time) * dropEnergy
                left = rainBed + dropEnergy * 0.22 + dropTone * 0.08
                right = midNoise.right * 0.17 + dropEnergy * 0.18 + dropTone * 0.06
            case .ocean:
                let swell = 0.20 + 0.80 * pow(0.5 + 0.5 * sin(slow * time / 9 + lowNoise.left * 2), 3)
                let crest = max(0, lowNoise.left - 0.10) * 0.65
                left = lowNoise.left * 0.32 * swell + sin(slow * 52 * time) * 0.06 * swell + crest
                right = lowNoise.right * 0.32 * swell + sin(slow * 58 * time + 0.6) * 0.055 * swell + max(0, lowNoise.right - 0.10) * 0.55
            case .fireplace:
                let flame = 0.16 + 0.12 * (0.5 + 0.5 * sin(slow * time / 2.6))
                left = lowNoise.left * 0.25 + midNoise.left * 0.12 + flame + crackleEnergy * 0.32
                right = lowNoise.right * 0.25 + midNoise.right * 0.12 + flame * 0.8 + crackleEnergy * 0.24
            case .forest:
                let wind = 0.35 + 0.65 * (0.5 + 0.5 * sin(slow * time / 11))
                let bird = birdEnergy * sin(slow * (1_100 + 420 * sin(slow * time / 7)) * time) * 0.16
                let rustle = midNoise.left * 0.06 * (0.6 + 0.4 * sin(slow * time / 4))
                left = lowNoise.left * 0.17 * wind + rustle + bird
                right = lowNoise.right * 0.17 * wind + rustle * 0.8 + bird * 0.72
            case .stream:
                let current = 0.5 + 0.5 * sin(slow * time / 5.5)
                left = midNoise.left * 0.23 * current + sin(slow * 3.2 * time) * 0.08 + bubbleEnergy * 0.12
                right = midNoise.right * 0.23 * current + sin(slow * 4.1 * time + 0.8) * 0.075 + bubbleEnergy * 0.08
            case .softWind:
                let gust = 0.25 + 0.75 * (0.5 + 0.5 * sin(slow * time / 10))
                let whistle = sin(slow * 240 * time + sin(slow * time / 5) * 2) * 0.045
                left = lowNoise.left * 0.42 * gust + whistle * gust
                right = lowNoise.right * 0.42 * gust + whistle * 0.8 * gust
            case .morningBirds:
                let cricket = max(0, sin(slow * 3.7 * time + lowNoise.left * 3)) * 0.10
                let owl = birdEnergy * sin(slow * 530 * time) * 0.10
                left = sin(slow * 82 * time) * 0.07 + cricket + owl + lowNoise.left * 0.018
                right = sin(slow * 82 * time + 0.5) * 0.06 + cricket * 0.8 + owl * 0.75 + lowNoise.right * 0.018
            case .deepSpace:
                let drone = sin(slow * 48 * time) * 0.13 + sin(slow * 73 * time) * 0.07
                let shimmer = sin(slow * (220 + 35 * sin(slow * time / 8)) * time) * 0.08
                let beacon = pow(max(0, sin(slow * 0.17 * time)), 12) * sin(slow * 880 * time) * 0.08
                left = drone + shimmer + beacon + lowNoise.left * 0.015
                right = sin(slow * 48 * time + 0.8) * 0.13 + sin(slow * 73 * time + 0.3) * 0.07 + shimmer * 0.7 + beacon * 0.8 + lowNoise.right * 0.015
            }

            let leftSample = Int16(max(-0.9, min(0.9, left * loopFade)) * Double(Int16.max))
            let rightSample = Int16(max(-0.9, min(0.9, right * loopFade)) * Double(Int16.max))
            samples[frame * channels] = leftSample.littleEndian
            samples[frame * channels + 1] = rightSample.littleEndian
        }
        let pcm = samples.withUnsafeBytes { Data($0) }
        var header = Data()
        header.append(contentsOf: Array("RIFF".utf8))
        header.append(contentsOf: withUnsafeBytes(of: UInt32(36 + pcm.count).littleEndian, Array.init))
        header.append(contentsOf: Array("WAVEfmt ".utf8))
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * channels * 2).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: UInt16(channels * 2).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian, Array.init))
        header.append(contentsOf: Array("data".utf8))
        header.append(contentsOf: withUnsafeBytes(of: UInt32(pcm.count).littleEndian, Array.init))
        header.append(pcm)
        return header
    }

    func importAudio(from sourceURL: URL) {
        let continuePlaying = isPlaying
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        do {
            let values = try sourceURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true, let size = values.fileSize, size > 0, size <= 250 * 1024 * 1024 else {
                throw CocoaError(.fileReadTooLarge)
            }
            let candidate = try AVAudioPlayer(contentsOf: sourceURL)
            candidate.prepareToPlay()
            let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ImportedAudio", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let ext = sourceURL.pathExtension.isEmpty ? "audio" : sourceURL.pathExtension.lowercased()
            let destinationFileName = "focus-music-\(UUID().uuidString).\(ext)"
            let destination = folder.appendingPathComponent(destinationFileName)
            let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
            try data.write(to: destination, options: .atomic)
            let importedTrack = ImportedTrack(
                id: UUID(),
                title: sourceURL.deletingPathExtension().lastPathComponent,
                fileName: destinationFileName
            )
            let replacement: AVAudioPlayer
            do { replacement = try AVAudioPlayer(contentsOf: destination) }
            catch { try? FileManager.default.removeItem(at: destination); throw error }
            player?.stop()
            player = replacement
            player?.numberOfLoops = -1
            player?.volume = isMuted ? 0 : volume
            player?.prepareToPlay()
            isAvailable = true
            isPlaying = false
            hasImportedAudio = true
            selectedImportedTrackID = importedTrack.id
            importedTracks.append(importedTrack)
            saveImportedTracks()
            trackName = importedTrack.title
            UserDefaults.standard.set(trackName, forKey: importedTrackNameKey)
            UserDefaults.standard.set(true, forKey: useImportedAudioKey)
            UserDefaults.standard.set(importedTrack.id.uuidString, forKey: selectedImportedTrackKey)
            errorMessage = nil
            if continuePlaying { play() }
        } catch {
            errorMessage = "That file cannot be played on this device. Your previous music was kept."
        }
    }

    func selectImportedTrack(_ track: ImportedTrack) {
        guard let url = importedURL(for: track) else {
            importedTracks.removeAll { $0.id == track.id }
            saveImportedTracks()
            hasImportedAudio = !importedTracks.isEmpty
            if selectedImportedTrackID == track.id {
                let saved = UserDefaults.standard.string(forKey: soundscapeKey).flatMap(BuiltInSoundscape.init(rawValue:)) ?? .atmosphere
                selectBuiltInSoundscape(premiumAccess == false && saved.isPro ? .atmosphere : saved)
            }
            errorMessage = "That imported file is no longer available."
            return
        }
        do {
            let continuePlaying = isPlaying
            let importedPlayer = try AVAudioPlayer(contentsOf: url)
            player?.stop()
            player = importedPlayer
            player?.numberOfLoops = -1
            player?.volume = isMuted ? 0 : volume
            player?.prepareToPlay()
            selectedImportedTrackID = track.id
            trackName = track.title
            hasImportedAudio = true
            isAvailable = true
            isPlaying = false
            UserDefaults.standard.set(track.id.uuidString, forKey: selectedImportedTrackKey)
            UserDefaults.standard.set(true, forKey: useImportedAudioKey)
            errorMessage = nil
            if continuePlaying { play() }
        } catch {
            errorMessage = "That imported file cannot be played on this device."
        }
    }

    func removeImportedAudio() {
        guard let selected = selectedImportedTrack else { return }
        if let url = importedURL(for: selected) {
            do { try FileManager.default.removeItem(at: url) }
            catch { errorMessage = "This file could not be removed. Please try again."; return }
        }
        stop()
        importedTracks.removeAll { $0.id == selected.id }
        selectedImportedTrackID = nil
        saveImportedTracks()
        UserDefaults.standard.removeObject(forKey: importedTrackNameKey)
        UserDefaults.standard.removeObject(forKey: selectedImportedTrackKey)
        UserDefaults.standard.set(false, forKey: useImportedAudioKey)

        let stored = UserDefaults.standard.string(forKey: soundscapeKey).flatMap(BuiltInSoundscape.init(rawValue:)) ?? .atmosphere
        let saved = premiumAccess == false && stored.isPro ? BuiltInSoundscape.atmosphere : stored
        do {
            player = try Self.makePlayer(for: saved)
            player?.numberOfLoops = -1
            player?.volume = isMuted ? 0 : volume
            player?.prepareToPlay()
            selectedSoundscape = saved
            trackName = saved.title
            hasImportedAudio = !importedTracks.isEmpty
            isAvailable = true
            errorMessage = nil
        } catch {
            player = nil
            hasImportedAudio = false
            isAvailable = false
            errorMessage = "Built-in focus audio could not be restored."
        }
    }

    private var importedAudioFolderURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImportedAudio", isDirectory: true)
    }

    private func importedURL(for track: ImportedTrack) -> URL? {
        guard !track.fileName.isEmpty, track.fileName == (track.fileName as NSString).lastPathComponent,
              track.fileName != ".", track.fileName != ".." else { return nil }
        let url = importedAudioFolderURL.appendingPathComponent(track.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func saveImportedTracks() {
        guard let data = try? JSONEncoder().encode(importedTracks) else { return }
        UserDefaults.standard.set(data, forKey: importedTracksKey)
    }

    private func loadImportedTracks() -> [ImportedTrack] {
        if let data = UserDefaults.standard.data(forKey: importedTracksKey),
           let tracks = try? JSONDecoder().decode([ImportedTrack].self, from: data) {
            return tracks.filter { importedURL(for: $0) != nil }
        }

        let files = (try? FileManager.default.contentsOfDirectory(at: importedAudioFolderURL, includingPropertiesForKeys: nil)) ?? []
        let legacyFiles = files.filter { $0.lastPathComponent.hasPrefix("focus-music.") }
        let legacyTitle = UserDefaults.standard.string(forKey: importedTrackNameKey) ?? "Imported focus music"
        let migrated = legacyFiles.map { file in
            ImportedTrack(id: UUID(), title: legacyTitle, fileName: file.lastPathComponent)
        }
        if !migrated.isEmpty { 
            if let data = try? JSONEncoder().encode(migrated) { UserDefaults.standard.set(data, forKey: importedTracksKey) }
        }
        return migrated
    }
    
    func play() {
        guard isAvailable else { isPlaying = false; return }
        let sessionActivated = activateAudioSession()

        player?.volume = isMuted ? 0 : volume
        player?.prepareToPlay()
        var success = player?.play() ?? false
        // AVAudioPlayer can lose its decoded buffers after a route change or
        // interruption. Reload once before reporting failure to the user.
        if !success {
            loadSound()
            player?.volume = isMuted ? 0 : volume
            player?.prepareToPlay()
            success = player?.play() ?? false
        }
        isPlaying = success
        if success {
            errorMessage = nil
        } else if sessionActivated {
            errorMessage = "Focus audio could not start on the current audio route."
        }
    }
    
    func pause() {
        resumeAfterInterruption = false
        player?.pause()
        isPlaying = false
    }
    
    func stop() {
        resumeAfterInterruption = false
        player?.stop()
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func setVolume(_ newVolume: Float) {
        let clampedVolume = max(0.0, min(1.0, newVolume))
        volume = clampedVolume
        player?.volume = isMuted ? 0 : clampedVolume
    }
    
    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            player?.volume = 0
        } else {
            player?.volume = volume
        }
    }
}

@MainActor
final class CompletionAlarmPlayer: ObservableObject {
    private enum Waveform { case sine, square, noise }
    private struct Note {
        let start: Double
        let duration: Double
        let frequency: Double
        let endFrequency: Double
        let gain: Float
        let waveform: Waveform

        init(_ start: Double, _ duration: Double, _ frequency: Double, _ endFrequency: Double? = nil, _ gain: Float = 0.28, _ waveform: Waveform = .sine) {
            self.start = start; self.duration = duration; self.frequency = frequency
            self.endFrequency = endFrequency ?? frequency; self.gain = gain; self.waveform = waveform
        }
    }

    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let speech = AVSpeechSynthesizer()
    private let sampleRate: Double
    var alarmSampleRate: Double { sampleRate }
    var nodeSampleRate: Double { node.outputFormat(forBus: 0).sampleRate }

    init(sampleRate: Double = 44_100) {
        self.sampleRate = sampleRate.isFinite && sampleRate >= 8_000 && sampleRate <= 192_000 ? sampleRate : 44_100
        engine.attach(node)
        // The mixer converts to the hardware rate. The node and generated
        // buffers must agree, otherwise scheduleBuffer can raise an Obj-C
        // exception that Swift's do/catch cannot catch.
        engine.connect(node, to: engine.mainMixerNode,
                       format: AVAudioFormat(standardFormatWithSampleRate: self.sampleRate, channels: 2))
    }

    func play(for theme: Theme) {
        stop()
        if theme == .word {
            let utterance = AVSpeechUtterance(string: "Time is up. Your focus session is complete.")
            utterance.rate = 0.48
            utterance.pitchMultiplier = 0.92
            speech.speak(utterance)
            return
        }

        let notes = recipe(for: theme)
        guard !notes.isEmpty else { return }
        let length = (notes.map { $0.start + $0.duration }.max() ?? 1) + 0.2
        let frameCount = AVAudioFrameCount(length * sampleRate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else { return }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            var value: Float = 0
            for note in notes where time >= note.start && time < note.start + note.duration {
                let local = time - note.start
                let phaseProgress = local / note.duration
                let frequency = note.frequency + (note.endFrequency - note.frequency) * phaseProgress
                let envelope = Float(sin(.pi * phaseProgress))
                switch note.waveform {
                case .sine:
                    value += sin(Float(2 * Double.pi * frequency * local)) * envelope * note.gain
                case .square:
                    value += (sin(2 * Double.pi * frequency * local) >= 0 ? 1 : -1) * envelope * note.gain
                case .noise:
                    let impulse: Float = Float.random(in: 0...1) < 0.018 ? 1 : 0.08
                    value += Float.random(in: -1...1) * envelope * note.gain * impulse
                }
            }
            let sample = max(-0.9, min(0.9, value))
            channels[0][frame] = sample
            channels[1][frame] = sample
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try engine.start()
            node.scheduleBuffer(buffer)
            node.play()
        } catch {
            stop()
        }
    }

    func stop() {
        speech.stopSpeaking(at: .immediate)
        node.stop()
        engine.stop()
    }

    private func recipe(for theme: Theme) -> [Note] {
        switch theme {
        case .analog: return [Note(0, 0.65, 880), Note(0.32, 0.9, 1_320, nil, 0.2)]
        case .steampunk: return [Note(0, 0.13, 1, nil, 0.55, .noise), Note(0.08, 0.55, 170, 95, 0.32), Note(0.55, 0.11, 1, nil, 0.45, .noise)]
        case .digital: return [Note(0, 0.14, 880, nil, 0.24, .square), Note(0.22, 0.14, 1_100, nil, 0.24, .square), Note(0.44, 0.32, 1_320, nil, 0.22, .square)]
        case .hourglass: return (0..<8).map { Note(Double($0) * 0.09, 0.42, 1_500 - Double($0 * 95), nil, 0.09) }
        case .flip: return [Note(0, 0.09, 1, nil, 0.65, .noise), Note(0.16, 0.09, 1, nil, 0.65, .noise), Note(0.32, 0.16, 120, 70, 0.28)]
        case .word: return []
        case .railway: return [Note(0, 1.2, 620, 920, 0.22), Note(0.18, 1.1, 465, 680, 0.16)]
        case .water: return [Note(0, 0.42, 1_400, 520, 0.2), Note(0.34, 0.5, 1_100, 390, 0.18), Note(0.76, 0.56, 900, 310, 0.16)]
        case .zen: return [Note(0, 2.6, 220, 214, 0.28), Note(0, 2.2, 660, 642, 0.08)]
        case .solar: return [Note(0, 0.7, 523), Note(0.2, 0.8, 659, nil, 0.2), Note(0.4, 1.0, 784, nil, 0.18)]
        case .cosmos: return [Note(0, 1.8, 220, 1_320, 0.18), Note(0.25, 1.5, 440, 1_760, 0.1)]
        case .grandfather: return [Note(0, 0.7, 659), Note(0.38, 0.75, 523), Note(0.76, 0.75, 587), Note(1.14, 1.2, 392, nil, 0.24)]
        case .cuckoo: return [Note(0, 0.26, 784), Note(0.25, 0.38, 659), Note(0.72, 0.26, 784), Note(0.97, 0.38, 659)]
        case .aurora: return [Note(0, 1.1, 440, 660, 0.14), Note(0.2, 1.2, 554, 880, 0.12), Note(0.4, 1.3, 659, 1_100, 0.1)]
        case .binary:
            return [1, 0, 1, 1, 0, 1].enumerated().map { index, bit in Note(Double(index) * 0.16, 0.1, bit == 1 ? 1_240 : 620, nil, 0.2, .square) }
        case .chronograph: return [Note(0, 0.09, 1_000, nil, 0.3, .square), Note(0.18, 0.09, 1_000, nil, 0.3, .square), Note(0.36, 0.38, 1_450, nil, 0.2)]
        case .world: return [Note(0, 0.85, 392), Note(0.22, 0.9, 523, nil, 0.2), Note(0.44, 1.0, 659, nil, 0.18)]
        case .candle: return [Note(0, 2.0, 1, nil, 0.5, .noise), Note(0.24, 0.28, 1_100, 1_750, 0.14), Note(0.72, 0.28, 1_250, 1_900, 0.14), Note(1.18, 0.32, 980, 1_650, 0.14)]
        case .stopwatch: return [Note(0, 0.08, 1_240, nil, 0.22, .square), Note(0.16, 0.08, 1_240, nil, 0.22, .square), Note(0.32, 0.28, 1_860, nil, 0.18, .square)]
        }
    }
}
