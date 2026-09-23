import Foundation
import SwiftUI

struct FocusSession: Identifiable, Codable {
    let id: UUID
    let completedAt: Date
    let duration: TimeInterval
    let intention: String
    let theme: String
}

@MainActor
final class FocusHistoryStore: ObservableObject {
    static let shared = FocusHistoryStore()
    @Published private(set) var sessions: [FocusSession] = []
    private let key = "completedFocusSessions"

    private init() { load() }

    func record(duration: TimeInterval, intention: String, theme: Theme) {
        sessions.insert(FocusSession(id: UUID(), completedAt: Date(), duration: duration, intention: intention, theme: theme.rawValue), at: 0)
        sessions = Array(sessions.prefix(100))
        save()
    }

    func delete(_ session: FocusSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    static func removing(_ offsets: IndexSet, from sessions: [FocusSession]) -> [FocusSession] {
        let ids = Set(offsets.compactMap { sessions.indices.contains($0) ? sessions[$0].id : nil })
        return sessions.filter { !ids.contains($0.id) }
    }

    func delete(at offsets: IndexSet) {
        sessions = Self.removing(offsets, from: sessions)
        save()
    }

    var totalMinutes: Int { Int(sessions.reduce(0) { $0 + $1.duration } / 60) }

    var currentStreak: Int {
        let calendar = Calendar.current
        let days = Set(sessions.map { calendar.startOfDay(for: $0.completedAt) })
        var day = calendar.startOfDay(for: Date())
        if !days.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) { day = yesterday }
        guard days.contains(day) else { return 0 }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) else { return }
        sessions = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct FocusHistoryView: View {
    @ObservedObject var history: FocusHistoryStore

    var body: some View {
        List {
            Section {
                HStack {
                    Label("Current streak", systemImage: "flame.fill")
                    Spacer()
                    Text("\(history.currentStreak) days").font(.headline)
                }
                HStack {
                    Label("Completed focus", systemImage: "clock.fill")
                    Spacer()
                    Text("\(history.totalMinutes) min").font(.headline)
                }
            }
            Section("Recent sessions") {
                if history.sessions.isEmpty {
                    Text("Complete a session to begin your history.").foregroundStyle(.secondary)
                } else {
                    ForEach(history.sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.intention.isEmpty ? "Focus session" : session.intention).font(.headline)
                            Text("\(Int(session.duration / 60)) min · \(session.theme) · \(session.completedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        history.delete(at: offsets)
                    }
                }
            }
        }
        .navigationTitle("Focus History")
    }
}
