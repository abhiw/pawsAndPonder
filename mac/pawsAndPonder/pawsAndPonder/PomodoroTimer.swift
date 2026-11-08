import Foundation
import Observation

@Observable final class PomodoroTimer {
    enum Phase {
        case work, rest

        var title: String {
            switch self {
            case .work: "Work"
            case .rest: "Break"
            }
        }

        var next: Phase { self == .work ? .rest : .work }
    }

    private(set) var phase: Phase = .work
    private(set) var remaining: TimeInterval = 0
    private(set) var isRunning = false
    /// Length of the current phase as it was loaded, so progress stays right if settings change mid-phase.
    private(set) var phaseDuration: TimeInterval = 1

    @ObservationIgnored let history: WorkHistory

    // Time is derived from an end date rather than counting ticks, so it stays
    // accurate across sleep and delayed ticks.
    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    // When the current run of a work phase started, so it can be recorded once it stops.
    @ObservationIgnored private var workRunStart: Date?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let onPhaseFinished: (Phase, Int) -> Void

    /// The defaults are what the app uses; tests pass their own settings, clock, history and alert.
    init(
        defaults: UserDefaults = .standard,
        history: WorkHistory = WorkHistory(),
        now: @escaping () -> Date = Date.init,
        onPhaseFinished: ((Phase, Int) -> Void)? = nil
    ) {
        self.defaults = defaults
        self.history = history
        self.now = now
        self.onPhaseFinished = onPhaseFinished ?? { PhaseAlerts.phaseDidFinish($0, nextMinutes: $1) }
        SettingsKey.registerDefaults(in: defaults)
        loadPhase()
    }

    /// How far through the current phase we are, from 0 (just started) to 1 (finished).
    var progress: Double {
        min(max(1 - remaining / phaseDuration, 0), 1)
    }

    /// Remaining time as mm:ss, rounded up so the display hits 00:00 only at the end.
    var formattedRemaining: String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Controls

    func start() {
        guard !isRunning else { return }
        endDate = now().addingTimeInterval(remaining)
        isRunning = true
        workRunStart = phase == .work ? now() : nil
        startTicking()
    }

    func pause() {
        guard isRunning, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSince(now()))
        stopTicking()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    /// Records the work time of a running phase so far, for example before the app quits.
    func recordProgress() {
        guard isRunning else { return }
        recordWorkRun()
        workRunStart = phase == .work ? now() : nil
    }

    /// Stops the timer and restores the full duration of the current phase.
    func reset() {
        stopTicking()
        loadPhase()
    }

    /// Call when the durations change. The current phase switches to its new length right away and
    /// keeps the time already elapsed. If more time has elapsed than the new length, the phase ends.
    func applySettings() {
        let newDuration = duration(of: phase)
        guard newDuration != phaseDuration else { return }

        // `remaining` is only refreshed on each tick, so work from the end time while running.
        if let endDate {
            remaining = max(0, endDate.timeIntervalSince(now()))
        }
        let elapsed = phaseDuration - remaining
        phaseDuration = newDuration
        remaining = max(phaseDuration - elapsed, 0)

        if remaining == 0 {
            completePhase()
        } else if isRunning {
            endDate = now().addingTimeInterval(remaining)
            startTicking()
        }
    }

    /// Moves to the other phase, staying paused or running as before.
    func skip() {
        let wasRunning = isRunning
        stopTicking()
        phase = phase.next
        loadPhase()
        if wasRunning { start() }
    }

    /// Brings `remaining` up to date and ends the phase when time is up. Called by the ticker.
    func tick() {
        guard let endDate else { return }
        remaining = max(0, endDate.timeIntervalSince(now()))
        if remaining == 0 { completePhase() }
    }

    // MARK: - Internals

    /// Sets the timer to a full-length current phase.
    private func loadPhase() {
        phaseDuration = duration(of: phase)
        remaining = phaseDuration
    }

    private func duration(of phase: Phase) -> TimeInterval {
        let key = phase == .work ? SettingsKey.workMinutes : SettingsKey.breakMinutes
        return TimeInterval(max(1, defaults.integer(forKey: key)) * 60)
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task {
            while !Task.isCancelled {
                // Wake just after the displayed second changes instead of polling, so the widget
                // redraws once a second. The tolerance lets the system batch wake-ups to save energy.
                let delay = remaining - remaining.rounded(.up) + 1.01
                try? await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(50))
                guard !Task.isCancelled else { return }
                tick()
            }
        }
    }

    /// Every way of stopping (pause, reset, skip, phase end) comes through here, so this is
    /// where a run of work gets recorded.
    private func stopTicking() {
        recordWorkRun()
        tickTask?.cancel()
        tickTask = nil
        endDate = nil
        isRunning = false
    }

    private func recordWorkRun() {
        guard let start = workRunStart else { return }
        workRunStart = nil
        guard defaults.bool(forKey: SettingsKey.keepHistory) else { return }
        // A late tick, for example after the Mac slept, mustn't count time past the end of the phase.
        let current = now()
        history.addWork(from: start, to: min(current, endDate ?? current))
    }

    private func completePhase() {
        let finished = phase
        stopTicking()
        phase = finished.next
        loadPhase()
        onPhaseFinished(finished, Int(remaining / 60))

        // Auto-start depends on which transition just happened.
        let key = finished == .work ? SettingsKey.autoStartBreak : SettingsKey.autoStartWork
        if defaults.bool(forKey: key) { start() }
    }
}
