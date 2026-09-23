import Foundation
@preconcurrency import UserNotifications

@MainActor
final class FocusScheduleStore: ObservableObject {
    static let shared = FocusScheduleStore()
    @Published var enabled: Bool { didSet { persistAndSchedule() } }
    @Published var hour: Int { didSet { persistAndSchedule() } }
    @Published var minute: Int { didSet { persistAndSchedule() } }
    @Published private(set) var message: String?

    private let identifier = "donenow.daily-focus-reminder"
    private let gate = NotificationRequestGate()

    private init() {
        enabled = UserDefaults.standard.bool(forKey: "dailyFocusReminderEnabled")
        hour = UserDefaults.standard.object(forKey: "dailyFocusReminderHour") as? Int ?? 9
        minute = UserDefaults.standard.object(forKey: "dailyFocusReminderMinute") as? Int ?? 0
        message = nil
    }

    private func persistAndSchedule() {
        message = nil
        UserDefaults.standard.set(enabled, forKey: "dailyFocusReminderEnabled")
        UserDefaults.standard.set(hour, forKey: "dailyFocusReminderHour")
        UserDefaults.standard.set(minute, forKey: "dailyFocusReminderMinute")
        let center = UNUserNotificationCenter.current()
        let token = gate.begin(prefix: identifier)
        guard enabled else { return }
        let hour = hour
        let minute = minute
        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard gate.isCurrent(token), enabled else { return }
            guard granted else {
                self.message = "Notifications are off. Enable them in Settings to receive daily reminders."
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "DoneNow"
            content.body = "Your scheduled focus session is ready."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
            let request = UNNotificationRequest(identifier: gate.identifier(prefix: identifier, token: token), content: content, trigger: trigger)
            do {
                try await center.add(request)
                gate.didAdd(prefix: identifier, token: token)
            } catch {
                guard gate.isCurrent(token) else { return }
                self.message = "The daily reminder could not be scheduled."
            }
        }
    }
}
