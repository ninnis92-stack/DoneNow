import Foundation
import UserNotifications

@MainActor
final class CompletionNotificationScheduler: ObservableObject {
    private let identifier = "donenow.focus-complete"
    private let gate = NotificationRequestGate()
    @Published private(set) var errorMessage: String?

    func schedule(after interval: TimeInterval, intention: String, message: String) {
        errorMessage = nil
        let center = UNUserNotificationCenter.current()
        let token = gate.begin(prefix: identifier)
        let deadline = Date().addingTimeInterval(interval)
        Task { @MainActor in
            let settings = await center.notificationSettings()
            var authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            if settings.authorizationStatus == .notDetermined {
                authorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            }
            guard gate.isCurrent(token) else { return }
            guard authorized else {
                self.errorMessage = "Notifications are off. Enable them in Settings to be alerted when your session ends."
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "DoneNow"
            // Keep private focus intentions off the lock screen. The full
            // intention remains available in DoneNow's completion screen.
            content.body = message
            content.sound = .default
            guard let remaining = NotificationRequestGate.remaining(until: deadline) else { return }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
            let request = UNNotificationRequest(identifier: gate.identifier(prefix: identifier, token: token), content: content, trigger: trigger)
            do {
                try await center.add(request)
                gate.didAdd(prefix: identifier, token: token)
            } catch {
                guard gate.isCurrent(token) else { return }
                self.errorMessage = "The completion notification could not be scheduled."
            }
        }
    }

    func cancel() {
        errorMessage = nil
        gate.invalidate(legacyIdentifier: identifier)
    }
}
