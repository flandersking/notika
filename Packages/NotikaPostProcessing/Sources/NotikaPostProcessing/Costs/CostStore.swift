import Foundation
import NotikaCore

@MainActor
public final class CostStore {
    private let defaults: UserDefaults
    private let calendar: Calendar
    public var now: @Sendable () -> Date

    public init(defaults: UserDefaults = .standard,
                calendar: Calendar = Calendar.current,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    /// Speichert einen bereits berechneten USD-Betrag. `nil` = keine Kosten
    /// (z. B. lokale Ollama-Modelle oder Apple Foundation) → callCount zählt
    /// trotzdem, totalUSD bleibt unverändert.
    public func record(costUSD: Double?) {
        let cost = costUSD ?? 0

        var todaySnap = readSnapshot(key: dailyKey())
        todaySnap = CostSnapshot(
            totalUSD: todaySnap.totalUSD + cost,
            callCount: todaySnap.callCount + 1,
            lastReset: todaySnap.lastReset
        )
        writeSnapshot(todaySnap, key: dailyKey())

        var monthSnap = readSnapshot(key: monthlyKey())
        monthSnap = CostSnapshot(
            totalUSD: monthSnap.totalUSD + cost,
            callCount: monthSnap.callCount + 1,
            lastReset: monthSnap.lastReset
        )
        writeSnapshot(monthSnap, key: monthlyKey())
    }

    public func today() -> CostSnapshot {
        readSnapshot(key: dailyKey())
    }

    public func thisMonth() -> CostSnapshot {
        readSnapshot(key: monthlyKey())
    }

    public func resetToday() {
        defaults.removeObject(forKey: dailyKey())
    }

    // MARK: - Persistence helpers

    private func dailyKey() -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: now())
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "notika.costs.daily.%04d-%02d-%02d", y, m, d)
    }

    private func monthlyKey() -> String {
        let comps = calendar.dateComponents([.year, .month], from: now())
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        return String(format: "notika.costs.monthly.%04d-%02d", y, m)
    }

    private func readSnapshot(key: String) -> CostSnapshot {
        guard let data = defaults.data(forKey: key),
              let snap = try? JSONDecoder().decode(CostSnapshot.self, from: data)
        else { return CostSnapshot(lastReset: now()) }
        return snap
    }

    private func writeSnapshot(_ snap: CostSnapshot, key: String) {
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: key)
        }
    }
}
