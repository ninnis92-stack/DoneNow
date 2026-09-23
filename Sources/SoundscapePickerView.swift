import SwiftUI

/// A persistent chooser, independent of the clock's frame-by-frame updates.
/// Selecting another track deliberately leaves the chooser and playback open.
struct SoundscapePickerView: View {
    @ObservedObject var audio: AudioPlayer
    let hasPro: Bool
    let requestPro: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(audio.isPlaying ? "Music is playing" : "Music is paused",
                          systemImage: audio.isPlaying ? "waveform" : "pause.fill")
                    Text("Choose another sound without pausing your session. Your volume and mute setting stay the same.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !audio.importedTracks.isEmpty {
                    Section("Your music") {
                        ForEach(audio.importedTracks) { track in
                            Button { audio.selectImportedTrack(track) } label: {
                                row(track.title, selected: audio.selectedImportedTrackID == track.id, locked: false)
                            }
                        }
                    }
                }
                Section("Free soundscapes") {
                    ForEach(AudioPlayer.BuiltInSoundscape.allCases.filter { !$0.isPro }) { sound in
                        soundButton(sound)
                    }
                }
                Section("Pro soundscapes") {
                    ForEach(AudioPlayer.BuiltInSoundscape.allCases.filter(\.isPro)) { sound in
                        soundButton(sound)
                    }
                }
                if let error = audio.errorMessage {
                    Section { Text(error).foregroundStyle(.orange) }
                }
            }
            .navigationTitle("Choose Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func soundButton(_ sound: AudioPlayer.BuiltInSoundscape) -> some View {
        Button {
            if sound.isPro && !hasPro { requestPro() }
            else { audio.selectBuiltInSoundscape(sound) }
        } label: {
            row(sound.title, selected: audio.selectedImportedTrackID == nil && audio.selectedSoundscape == sound,
                locked: sound.isPro && !hasPro)
        }
        .accessibilityIdentifier("soundscape.\(sound.rawValue)")
    }

    private func row(_ title: String, selected: Bool, locked: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(.primary)
            Spacer()
            if locked { Image(systemName: "lock.fill").accessibilityLabel("Requires Pro") }
            else if selected { Image(systemName: "checkmark").accessibilityLabel("Selected") }
        }
        .frame(minHeight: 32).contentShape(Rectangle())
    }
}
