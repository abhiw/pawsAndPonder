import Foundation
import Testing
@testable import pawsAndPonder

/// A clock the tests move forward by hand, so a 25-minute phase can pass instantly.
final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func advance(_ seconds: TimeInterval) {
        now += seconds
    }
}

/// Separate settings and a throwaway history file for one test, so the app's real settings and
/// history are never touched.
@MainActor
final class TestEnvironment {
    // One fixed settings domain, cleared at the start of every test. A fresh domain per test would
    // leave a settings file behind each time, since the system writes those files lazily.
    private static let suiteName = "MyAppTests"

    let defaults: UserDefaults
    let historyURL = FileManager.default.temporaryDirectory.appending(path: "WorkHistory-\(UUID().uuidString).json")
    let clock = TestClock()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)
    }

    deinit {
        try? FileManager.default.removeItem(at: historyURL)
    }

    func makeHistory() -> WorkHistory {
        let clock = clock
        return WorkHistory(fileURL: historyURL, now: { clock.now })
    }
}

// MARK: - Timer

// Serialized because every test shares the one test settings domain.
@MainActor
@Suite(.serialized)
struct PomodoroTimerTests {
    /// Phase-end alerts the timer reported, instead of real sounds and notifications.
    final class AlertLog {
        var entries: [(phase: PomodoroTimer.Phase, nextMinutes: Int)] = []
    }

    let environment: TestEnvironment
    let alerts = AlertLog()

    init() throws {
        environment = try TestEnvironment()
    }

    private var clock: TestClock { environment.clock }

    private func makeTimer(
        workMinutes: Int = 25,
        breakMinutes: Int = 5,
        autoStartBreak: Bool = true,
        autoStartWork: Bool = false,
        keepHistory: Bool = false
    ) -> PomodoroTimer {
        let defaults = environment.defaults
        defaults.set(workMinutes, forKey: SettingsKey.workMinutes)
        defaults.set(breakMinutes, forKey: SettingsKey.breakMinutes)
        defaults.set(autoStartBreak, forKey: SettingsKey.autoStartBreak)
        defaults.set(autoStartWork, forKey: SettingsKey.autoStartWork)
        defaults.set(keepHistory, forKey: SettingsKey.keepHistory)
        let clock = clock
        let alerts = alerts
        return PomodoroTimer(
            defaults: defaults,
            history: environment.makeHistory(),
            now: { clock.now },
            onPhaseFinished: { alerts.entries.append(($0, $1)) }
        )
    }

    @Test func startsIdleAtFullWorkLength() {
        let timer = makeTimer()
        #expect(timer.phase == .work)
        #expect(!timer.isRunning)
        #expect(timer.remaining == 25 * 60)
        #expect(timer.progress == 0)
        #expect(timer.formattedRemaining == "25:00")
    }

    @Test func countsDownWhileRunning() {
        let timer = makeTimer()
        timer.start()
        clock.advance(61)
        timer.tick()
        #expect(timer.remaining == 25 * 60 - 61)
        #expect(timer.formattedRemaining == "23:59")
        #expect(abs(timer.progress - 61.0 / 1500) < 0.0001)
    }

    @Test func displayRoundsUpPartialSeconds() {
        let timer = makeTimer()
        timer.start()
        clock.advance(0.5)
        timer.tick()
        // 24:59.5 left still shows the full second.
        #expect(timer.formattedRemaining == "25:00")
    }

    @Test func pauseFreezesRemainingTime() {
        let timer = makeTimer()
        timer.start()
        clock.advance(30)
        timer.pause()
        clock.advance(600) // time passing while paused doesn't count
        timer.start()
        timer.tick()
        #expect(timer.remaining == 25 * 60 - 30)
    }

    @Test func workEndAutoStartsBreakAndAlerts() {
        let timer = makeTimer(autoStartBreak: true)
        timer.start()
        clock.advance(25 * 60)
        timer.tick()
        #expect(timer.phase == .rest)
        #expect(timer.isRunning)
        #expect(timer.remaining == 5 * 60)
        #expect(alerts.entries.count == 1)
        #expect(alerts.entries.first?.phase == .work)
        #expect(alerts.entries.first?.nextMinutes == 5)
    }

    @Test func breakEndWaitsWhenAutoStartWorkIsOff() {
        let timer = makeTimer(autoStartBreak: true, autoStartWork: false)
        timer.start()
        clock.advance(25 * 60)
        timer.tick()
        clock.advance(5 * 60)
        timer.tick()
        #expect(timer.phase == .work)
        #expect(!timer.isRunning)
        #expect(timer.remaining == 25 * 60)
    }

    @Test func resetRestoresFullLengthAndStops() {
        let timer = makeTimer()
        timer.start()
        clock.advance(100)
        timer.reset()
        #expect(!timer.isRunning)
        #expect(timer.phase == .work)
        #expect(timer.remaining == 25 * 60)
    }

    @Test func skipKeepsRunningOrPausedState() {
        let timer = makeTimer()
        timer.skip()
        #expect(timer.phase == .rest)
        #expect(!timer.isRunning)

        timer.start()
        timer.skip()
        #expect(timer.phase == .work)
        #expect(timer.isRunning)
        #expect(timer.remaining == 25 * 60)
        // Skipping isn't finishing, so there's no alert.
        #expect(alerts.entries.isEmpty)
    }

    @Test func longerLengthMidPhaseKeepsElapsedTime() {
        let timer = makeTimer(workMinutes: 1)
        timer.start()
        clock.advance(30)
        environment.defaults.set(180, forKey: SettingsKey.workMinutes)
        timer.applySettings()
        #expect(timer.isRunning)
        #expect(timer.phaseDuration == 180 * 60)
        #expect(timer.remaining == 180 * 60 - 30)

        clock.advance(10)
        timer.tick()
        #expect(timer.remaining == 180 * 60 - 40)
    }

    @Test func shorterLengthThanElapsedEndsPhase() {
        let timer = makeTimer(workMinutes: 25, autoStartBreak: false)
        timer.start()
        clock.advance(10 * 60)
        environment.defaults.set(5, forKey: SettingsKey.workMinutes)
        timer.applySettings()
        #expect(timer.phase == .rest)
        #expect(!timer.isRunning)
        #expect(alerts.entries.count == 1)
    }

    @Test func shorterLengthWhilePausedAlsoEndsPhase() {
        let timer = makeTimer(workMinutes: 25, autoStartBreak: false)
        timer.start()
        clock.advance(10 * 60)
        timer.pause()
        environment.defaults.set(5, forKey: SettingsKey.workMinutes)
        timer.applySettings()
        #expect(timer.phase == .rest)
        #expect(timer.remaining == 5 * 60)
    }

    @Test func changingTheOtherPhaseLengthLeavesCurrentPhaseAlone() {
        let timer = makeTimer()
        timer.start()
        clock.advance(60)
        timer.tick()
        environment.defaults.set(15, forKey: SettingsKey.breakMinutes)
        timer.applySettings()
        #expect(timer.remaining == 25 * 60 - 60)
        #expect(timer.phaseDuration == 25 * 60)
    }

    // MARK: History recording

    @Test func recordsWorkTimeOnPauseWhenHistoryIsOn() {
        let timer = makeTimer(keepHistory: true)
        timer.start()
        clock.advance(90)
        timer.pause()
        #expect(timer.history.secondsByDay[WorkHistory.key(for: clock.now)] == 90)
    }

    @Test func recordsNothingWhenHistoryIsOff() {
        let timer = makeTimer(keepHistory: false)
        timer.start()
        clock.advance(90)
        timer.pause()
        #expect(timer.history.secondsByDay.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: environment.historyURL.path))
    }

    @Test func doesNotRecordBreakTime() {
        let timer = makeTimer(keepHistory: true)
        timer.skip() // to the break
        timer.start()
        clock.advance(120)
        timer.pause()
        #expect(timer.history.secondsByDay.isEmpty)
    }

    @Test func lateTickAfterSleepCountsOnlyThePhaseLength() {
        let timer = makeTimer(autoStartBreak: false, keepHistory: true)
        timer.start()
        clock.advance(25 * 60 + 3600) // the Mac slept past the end of the phase
        timer.tick()
        #expect(timer.phase == .rest)
        let recorded = timer.history.secondsByDay.values.reduce(0, +)
        #expect(recorded == 25 * 60)
    }

    @Test func recordProgressSavesSoFarAndKeepsCounting() {
        let timer = makeTimer(keepHistory: true)
        timer.start()
        clock.advance(60)
        timer.recordProgress()
        #expect(timer.isRunning)
        clock.advance(40)
        timer.pause()
        #expect(timer.history.secondsByDay[WorkHistory.key(for: clock.now)] == 100)
    }
}

// MARK: - History file

@MainActor
struct WorkHistoryTests {
    let environment: TestEnvironment

    init() throws {
        environment = try TestEnvironment()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) throws -> Date {
        try #require(Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }

    @Test func keysAreZeroPaddedLocalDates() throws {
        #expect(WorkHistory.key(for: try date(2026, 3, 7)) == "2026-03-07")
    }

    @Test func splitsWorkAcrossMidnight() throws {
        environment.clock.now = try date(2026, 3, 11)
        let history = environment.makeHistory()
        history.addWork(from: try date(2026, 3, 10, 23, 30), to: try date(2026, 3, 11, 0, 45))
        #expect(history.secondsByDay["2026-03-10"] == 1800)
        #expect(history.secondsByDay["2026-03-11"] == 2700)
    }

    @Test func addsUpSeveralRunsOnTheSameDay() throws {
        environment.clock.now = try date(2026, 3, 10, 18)
        let history = environment.makeHistory()
        history.addWork(from: try date(2026, 3, 10, 9), to: try date(2026, 3, 10, 10))
        history.addWork(from: try date(2026, 3, 10, 14), to: try date(2026, 3, 10, 14, 30))
        #expect(history.secondsByDay["2026-03-10"] == 5400)
    }

    @Test func ignoresEmptyOrBackwardsRuns() throws {
        environment.clock.now = try date(2026, 3, 10)
        let history = environment.makeHistory()
        history.addWork(from: try date(2026, 3, 10, 10), to: try date(2026, 3, 10, 10))
        history.addWork(from: try date(2026, 3, 10, 11), to: try date(2026, 3, 10, 10))
        #expect(history.secondsByDay.isEmpty)
    }

    @Test func keepsOnlyTheLastFourMonths() throws {
        environment.clock.now = try date(2026, 11, 8)
        let history = environment.makeHistory()
        history.addWork(from: try date(2026, 7, 7, 9), to: try date(2026, 7, 7, 10)) // one day too old
        history.addWork(from: try date(2026, 7, 8, 9), to: try date(2026, 7, 8, 10)) // exactly 4 months ago
        history.addWork(from: try date(2026, 11, 7, 9), to: try date(2026, 11, 7, 10))
        #expect(Set(history.secondsByDay.keys) == ["2026-07-08", "2026-11-07"])
    }

    @Test func savesAndReloads() throws {
        environment.clock.now = try date(2026, 3, 10, 18)
        environment.makeHistory().addWork(from: try date(2026, 3, 10, 9), to: try date(2026, 3, 10, 10))
        let reloaded = environment.makeHistory()
        #expect(reloaded.secondsByDay["2026-03-10"] == 3600)
    }

    @Test func dropsTooOldDaysWhenLoading() throws {
        environment.clock.now = try date(2026, 3, 10)
        environment.makeHistory().addWork(from: try date(2026, 3, 9, 9), to: try date(2026, 3, 9, 10))
        // Five months later, that day is past the cutoff.
        environment.clock.now = try date(2026, 8, 10)
        #expect(environment.makeHistory().secondsByDay.isEmpty)
    }

    @Test func corruptFileStartsEmpty() throws {
        try Data("not json".utf8).write(to: environment.historyURL)
        #expect(environment.makeHistory().secondsByDay.isEmpty)
    }

    @Test func readingDoesNotCreateAFile() {
        _ = environment.makeHistory().secondsByDay
        #expect(!FileManager.default.fileExists(atPath: environment.historyURL.path))
    }
}

// MARK: - Formatting and input rules

@MainActor
struct FormattingTests {
    static let durationCases: [(Double, String)] = [
        (0, "No work"),
        (30, "Less than 1 min"),
        (60, "1 min"),
        (3599, "59 min"),
        (3600, "1 h"),
        (9000, "2.5 h"),
        (10_656, "3 h") // 2.96 h rounds to a whole hour
    ]

    @Test(arguments: durationCases)
    func durationText(seconds: Double, expected: String) {
        #expect(HistoryView.formatDuration(seconds) == expected)
    }

    @Test func hourBands() {
        #expect(HistoryView.band(for: 0) == nil)
        #expect(HistoryView.band(for: 1) == 0)
        #expect(HistoryView.band(for: 3599) == 0)
        #expect(HistoryView.band(for: 3600) == 1)
        #expect(HistoryView.band(for: 7200) == 2)
        #expect(HistoryView.band(for: 14_400) == 3)
        #expect(HistoryView.band(for: 50_000) == 3)
    }

    @Test func minutesFieldKeepsOnlyDigits() {
        #expect(MinutesField.digitsOnly("1a2b3", maxLength: 3) == "123")
        #expect(MinutesField.digitsOnly("-5", maxLength: 3) == "5")
        #expect(MinutesField.digitsOnly("12345", maxLength: 3) == "123")
        #expect(MinutesField.digitsOnly(" 4 5 ", maxLength: 2) == "45")
        // Non-ASCII digits, such as full-width ones, are rejected.
        #expect(MinutesField.digitsOnly("１２", maxLength: 3) == "")
    }

    @Test func minutesFieldClampsCommittedValue() {
        let range = 1...180
        #expect(MinutesField.committedValue(from: "45", current: 25, range: range) == 45)
        #expect(MinutesField.committedValue(from: "0", current: 25, range: range) == 1)
        #expect(MinutesField.committedValue(from: "999", current: 25, range: range) == 180)
        #expect(MinutesField.committedValue(from: "", current: 25, range: range) == 25)
    }

    @Test func widgetTimeAreaWidth() {
        #expect(WidgetView.timeAreaWidth(style: .digital, barWidth: 300) == 104)
        #expect(WidgetView.timeAreaWidth(style: .bar, barWidth: 200) == 200)
        #expect(WidgetView.timeAreaWidth(style: .bar, barWidth: 10) == 80)
        #expect(WidgetView.timeAreaWidth(style: .bar, barWidth: 1000) == 400)
    }
}
