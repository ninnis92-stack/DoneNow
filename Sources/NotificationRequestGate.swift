import Foundation
import UserNotifications

/// Each revision has a different identifier, so a late completion can remove
/// only its own stale request, never a newer session's notification.
@MainActor
final class NotificationRequestGate {
    private var revision = UUID()
    private var identifiers = Set<String>()
    private let remove: ([String]) -> Void

    init(remove: @escaping ([String]) -> Void = {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: $0)
    }) { self.remove = remove }

    func invalidate(legacyIdentifier: String) {
        revision = UUID()
        let key = "notificationGate.\(legacyIdentifier)"
        let saved = UserDefaults.standard.stringArray(forKey: key) ?? []
        remove(Array(identifiers) + saved + [legacyIdentifier])
        UserDefaults.standard.removeObject(forKey: key)
        identifiers.removeAll()
    }

    func begin(prefix: String) -> UUID {
        invalidate(legacyIdentifier: prefix)
        identifiers.insert(identifier(prefix: prefix, token: revision))
        UserDefaults.standard.set(Array(identifiers), forKey: "notificationGate.\(prefix)")
        return revision
    }

    func isCurrent(_ token: UUID) -> Bool { token == revision }
    func identifier(prefix: String, token: UUID) -> String { "\(prefix).\(token.uuidString)" }
    func didAdd(prefix: String, token: UUID) {
        if !isCurrent(token) { remove([identifier(prefix: prefix, token: token)]) }
    }

    static func remaining(until deadline: Date, now: Date = Date()) -> TimeInterval? {
        let value = deadline.timeIntervalSince(now)
        return value.isFinite && value > 0 ? max(1, value) : nil
    }
}
