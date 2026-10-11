import Foundation
import UIKit

/// Anonymous usage, so we can tell whether anyone gets past setup and comes
/// back. What leaves the phone: a random install ID made here, one of six
/// event names, the local date and the app version. No habit names, no
/// counts, nothing tied to a person. Settings has the off switch.
enum UsageEvent: String, CaseIterable {
    case firstOpen = "first_open"
    /// Already had habits when this build arrived; kept out of the funnel.
    case upgrade
    case onboarded
    case firstHabit = "first_habit"
    case firstCompletion = "first_completion"
    /// At most once a local day.
    case active
}

/// Pure: which events are still owed.
enum UsagePlanner {
    struct State {
        var onboarded: Bool
        var hasHabit: Bool
        var hasCompletion: Bool
    }

    /// The first event an install sends, decided once and remembered so a
    /// failed `first_open` can't later turn into an `upgrade`.
    static func opening(_ state: State) -> UsageEvent {
        state.onboarded || state.hasHabit ? .upgrade : .firstOpen
    }

    static func due(opening: UsageEvent, sent: Set<UsageEvent>, lastActiveDay: Int, today: Int, state: State) -> [UsageEvent] {
        var events: [UsageEvent] = []
        if !sent.contains(opening) { events.append(opening) }
        if state.onboarded && !sent.contains(.onboarded) { events.append(.onboarded) }
        if state.hasHabit && !sent.contains(.firstHabit) { events.append(.firstHabit) }
        if state.hasCompletion && !sent.contains(.firstCompletion) { events.append(.firstCompletion) }
        if lastActiveDay != today { events.append(.active) }
        return events
    }

    /// 20261011 → "2026-10-11"
    static func dayString(_ key: Int) -> String {
        String(format: "%04d-%02d-%02d", key / 10000, key / 100 % 100, key % 100)
    }
}

@MainActor
final class UsageReporter {
    static let shared = UsageReporter()
    static let endpoint = URL(string: "https://continuum-api.orion-labs.workers.dev")!

    private static let enabledKey = "shareUsage"
    private let defaults = UserDefaults.standard
    private var inFlight: Set<UsageEvent> = []

    /// On unless the user turns it off in Settings.
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        #if DEBUG
        return v + "-debug"
        #else
        return v
        #endif
    }

    private var installID: String {
        if let id = defaults.string(forKey: "usageInstallID") { return id }
        let id = UUID().uuidString.lowercased()
        defaults.set(id, forKey: "usageInstallID")
        return id
    }

    func report(_ state: UsagePlanner.State) {
        guard Self.enabled else { return }
        #if DEBUG
        // Simulator and screenshot runs stay out of the numbers unless asked for.
        guard ProcessInfo.processInfo.environment["CONTINUUM_USAGE_DEBUG"] != nil else { return }
        #endif

        let opening = defaults.string(forKey: "usageOpening").flatMap(UsageEvent.init) ?? {
            let event = UsagePlanner.opening(state)
            defaults.set(event.rawValue, forKey: "usageOpening")
            return event
        }()
        let sent = Set((defaults.stringArray(forKey: "usageSent") ?? []).compactMap(UsageEvent.init))
        let today = ContinuumDay.todayKey()
        let due = UsagePlanner.due(
            opening: opening,
            sent: sent,
            lastActiveDay: defaults.integer(forKey: "usageLastActiveDay"),
            today: today,
            state: state
        )
        for event in due where !inFlight.contains(event) {
            send(event, today: today)
        }
    }

    private func send(_ event: UsageEvent, today: Int) {
        inFlight.insert(event)
        let body: [String: String] = [
            "install": installID,
            "event": event.rawValue,
            "day": UsagePlanner.dayString(today),
            "version": Self.version,
        ]
        Task {
            let ok = await Self.post("event", body)
            inFlight.remove(event)
            guard ok else { return }  // retried on the next foreground
            if event == .active {
                defaults.set(today, forKey: "usageLastActiveDay")
            } else {
                defaults.set((defaults.stringArray(forKey: "usageSent") ?? []) + [event.rawValue], forKey: "usageSent")
            }
        }
    }

    /// What the user typed into feedback. Sent without the install ID.
    static func sendFeedback(kind: String, text: String) async -> Bool {
        await post("feedback", [
            "kind": kind,
            "text": text,
            "version": version,
            "os": UIDevice.current.systemVersion,
        ])
    }

    private static func post(_ path: String, _ body: [String: String]) async -> Bool {
        var request = URLRequest(url: endpoint.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        request.timeoutInterval = 15
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
    }
}
