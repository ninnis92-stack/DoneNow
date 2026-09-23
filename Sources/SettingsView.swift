import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var store: ProStore
    @ObservedObject var history: FocusHistoryStore
    @Binding var developerProPreview: Bool
    let hasPro: Bool
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var ads = AdMobCoordinator.shared
    @AppStorage("completionHaptics") private var completionHaptics = true
    @AppStorage("completionSounds") private var completionSounds = true
    @AppStorage("autoPlayFocusAudio") private var autoPlayFocusAudio = true
    @AppStorage("autoPlayStopwatchAudio") private var autoPlayStopwatchAudio = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @State private var showingPrivacyPolicy = false
    @StateObject private var schedule = FocusScheduleStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("DoneNow Pro") {
                    Label("Nine premium clock faces", systemImage: "clock.badge.checkmark")
                    Label("Ad-free focus sessions", systemImage: "rectangle.slash")
                    Label("Focus history and streaks", systemImage: "chart.bar.xaxis")
                    Label("Daily focus reminders", systemImage: "bell.badge")
                    Label("Time Trial clock face", systemImage: "stopwatch.fill")
                    if hasPro {
                        Label("Pro is active", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            Text(store.isLoading ? "Checking Pro availability…" : store.product.map { "Buy Pro · \($0.displayPrice)" } ?? "Try Again")
                        }
                        .disabled(store.isLoading || store.isPurchasing)
                        Button("Restore Purchases") { Task { await store.restore() } }
                    }
                    if let message = store.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }

                Section("Pro productivity") {
                    if hasPro {
                        NavigationLink("Focus history and streaks") { FocusHistoryView(history: history) }
                        Toggle("Daily focus reminder", isOn: $schedule.enabled)
                        if schedule.enabled {
                            DatePicker("Reminder time", selection: reminderDate, displayedComponents: .hourAndMinute)
                            Text("This reminds you to start a session; it does not start a timer or change Apple Focus automatically.")
                                .font(.caption).foregroundStyle(.secondary)
                            if let message = schedule.message {
                                Text(message).font(.caption).foregroundStyle(.orange)
                                Button("Open Notification Settings") {
                                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                }
                            }
                        }
                    } else {
                        Label("History, streaks, and scheduled reminders are Pro features.", systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                #if DEBUG
                Section("Developer Testing") {
                    Toggle("Preview Pro entitlement", isOn: $developerProPreview)
                    Text("This override exists only in Debug builds and never represents a purchase.").font(.caption).foregroundStyle(.secondary)
                }
                #endif

                Section("Focus Session") {
                    Toggle("Keep screen awake while focusing", isOn: $keepScreenAwake)
                    Toggle("Completion haptic", isOn: $completionHaptics)
                    Toggle("Theme completion alarm", isOn: $completionSounds)
                    LabeledContent("Custom session range", value: "1–180 minutes")
                    Text("The Time Trial clock face is a Pro feature. Selecting it changes the timer to count upward until you pause or finish and save the session.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Focus Music") {
                    Toggle("Start music with timer", isOn: $autoPlayFocusAudio)
                    Toggle("Start music with stopwatch", isOn: $autoPlayStopwatchAudio)
                    Text("Each mode remembers its own choice. When enabled, starting or resuming that mode plays your selected music; pausing it pauses the music. You can switch soundscapes during playback.")
                        .font(.caption).foregroundStyle(.secondary)
                    Label("Personal files stay on this device", systemImage: "folder.badge.plus")
                    Text("Add personal audio from Files. DoneNow does not copy protected streaming music.").font(.caption).foregroundStyle(.secondary)
                    LabeledContent("Built-in soundscapes", value: "5 free · 6 Pro")
                    Text("Free includes Timekeeper, Calm Ocean, Fireplace, Forest, and Quiet Stream. Pro unlocks six additional soundscapes.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Clock Faces") {
                    LabeledContent("Free clock faces", value: "10")
                    LabeledContent("Pro clock faces", value: "9")
                }

                Section("Privacy") {
                    if ads.privacyOptionsRequired {
                        Button("Ad Privacy Choices") { ads.showPrivacyOptions() }
                        if let message = ads.statusMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                    }
                    Text("Focus intentions and imported audio remain on this device. DoneNow currently has no analytics or account system.")
                    Button("Privacy Policy") { showingPrivacyPolicy = true }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showingPrivacyPolicy) { PrivacyPolicyView() }
        }
    }

    private var reminderDate: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: schedule.hour, minute: schedule.minute)) ?? Date()
            },
            set: { value in
                let components = Calendar.current.dateComponents([.hour, .minute], from: value)
                schedule.hour = components.hour ?? 9
                schedule.minute = components.minute ?? 0
            }
        )
    }
}
