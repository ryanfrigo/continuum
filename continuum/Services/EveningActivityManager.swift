import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Keeps the evening Live Activity in step with the habits: scheduled for
/// 9 pm while something is open today, updated as habits are marked in the
/// app, ended once all are done, the setting is off, or the day is over.
/// iOS 26+ (scheduled start); earlier versions keep plain notifications.
@MainActor
final class EveningActivityManager {
    static let shared = EveningActivityManager()

    private static let enabledKey = "eveningActivity"
    /// Off until the user turns it on in Settings.
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private var chain: Task<Void, Never>?

    func sync(habits: [Habit], now: Date = Date()) {
        #if canImport(ActivityKit) && os(iOS)
        guard #available(iOS 26.0, *) else { return }
        let todayKey = ContinuumDay.key(for: now)
        let (rows, open) = EveningActivityPlan.rows(
            habits.filter { !$0.isArchived }.map { ($0.name, $0.completedDayKeys) },
            todayKey: todayKey
        )
        let wanted = Self.enabled && open > 0
        let state = EveningActivityAttributes.ContentState(rows: rows, open: open)
        let content = ActivityContent(state: state, staleDate: EveningActivityPlan.midnight(after: now))
        let start = EveningActivityPlan.start(now: now)

        // Serialized, like notification syncs, so two quick marks can't both
        // decide to request a new activity
        let previous = chain
        chain = Task {
            await previous?.value
            var kept = false
            for activity in Activity<EveningActivityAttributes>.activities {
                if wanted && !kept && activity.attributes.dayKey == todayKey {
                    await activity.update(content)
                    kept = true
                } else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            guard wanted, !kept, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                _ = try Activity.request(
                    attributes: EveningActivityAttributes(dayKey: todayKey),
                    content: content,
                    pushType: nil,
                    style: .standard,
                    alertConfiguration: AlertConfiguration(
                        title: "\(open) still open today",
                        body: "Before midnight. One hold each.",
                        sound: .default
                    ),
                    start: start
                )
            } catch {
                print("Continuum: evening Live Activity not started: \(error)")
            }
        }
        #endif
    }
}
