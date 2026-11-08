import Foundation

/// Work time per day for the last few months, saved as a small JSON file.
final class WorkHistory {
    static let monthsKept = 4

    static let defaultFileURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appending(path: "WorkHistory.json")

    private let fileURL: URL?
    private let now: () -> Date
    // Read on first use, so nothing is loaded unless history is recorded or viewed.
    private lazy var days: [String: Double] = load()

    /// Seconds worked, keyed by local date, for example "2026-11-08".
    var secondsByDay: [String: Double] { days }

    /// The defaults are what the app uses; tests pass a temporary file and their own clock.
    init(fileURL: URL? = WorkHistory.defaultFileURL, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.now = now
    }

    /// Adds a stretch of work, split at midnight so each day gets its own share.
    func addWork(from start: Date, to end: Date) {
        let calendar = Calendar.current
        var segmentStart = start
        while segmentStart < end {
            let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: segmentStart)) ?? end
            let segmentEnd = min(end, nextMidnight)
            guard segmentEnd > segmentStart else { break }
            days[Self.key(for: segmentStart), default: 0] += segmentEnd.timeIntervalSince(segmentStart)
            segmentStart = segmentEnd
        }
        pruneOldDays()
        save()
    }

    static func key(for date: Date) -> String {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    private func load() -> [String: Double] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return stored.filter { $0.key >= cutoffKey }
    }

    private func pruneOldDays() {
        days = days.filter { $0.key >= cutoffKey }
    }

    /// The oldest day kept. Keys are zero-padded dates, so comparing them as strings compares the dates.
    private var cutoffKey: String {
        let cutoff = Calendar.current.date(byAdding: .month, value: -Self.monthsKept, to: now()) ?? now()
        return Self.key(for: cutoff)
    }

    private func save() {
        guard let fileURL, let data = try? JSONEncoder().encode(days) else { return }
        // History is a convenience; if saving fails the timer keeps working, so errors are ignored.
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
