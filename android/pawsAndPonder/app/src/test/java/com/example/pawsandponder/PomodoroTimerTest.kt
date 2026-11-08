package com.example.pawsandponder

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PomodoroTimerTest {
    private var now = 0L
    private var settings = SettingsData(autoStartBreak = false)
    private val finished = mutableListOf<Pair<Phase, Int>>()

    private fun timer() = PomodoroTimer(
        scope = CoroutineScope(Dispatchers.Unconfined),
        settings = { settings },
        history = WorkHistory(null),
        monotonicMs = { now },
        wallMs = { now },
        onPhaseFinished = { p, m -> finished += p to m },
    )

    @Test
    fun startsAtFullWorkLength() {
        val t = timer()
        assertEquals(25 * 60_000L, t.state.value.remainingMs)
        assertEquals("25:00", t.state.value.formatted)
    }

    @Test
    fun finishesPhaseAndReportsNextLength() {
        val t = timer()
        t.start()
        now += 25 * 60_000L
        t.tick()
        assertEquals(listOf(Phase.WORK to 5), finished)
        assertEquals(Phase.BREAK, t.state.value.phase)
        assertFalse(t.state.value.isRunning)
    }

    @Test
    fun autoStartsBreak() {
        settings = settings.copy(autoStartBreak = true)
        val t = timer()
        t.start()
        now += 25 * 60_000L
        t.tick()
        assertTrue(t.state.value.isRunning)
        assertEquals(Phase.BREAK, t.state.value.phase)
    }

    @Test
    fun changingLengthKeepsElapsedTime() {
        val t = timer()
        t.start()
        now += 10 * 60_000L
        settings = settings.copy(workMinutes = 30)
        t.applySettings()
        assertEquals(20 * 60_000L, t.pauseAndRemaining())
    }

    @Test
    fun shorteningBelowElapsedEndsPhase() {
        val t = timer()
        t.start()
        now += 10 * 60_000L
        settings = settings.copy(workMinutes = 5)
        t.applySettings()
        assertEquals(Phase.BREAK, t.state.value.phase)
        assertEquals(1, finished.size)
    }

    @Test
    fun pauseKeepsRemainingAndSkipSwitchesPhase() {
        val t = timer()
        t.start()
        now += 60_000L
        t.pause()
        assertEquals(24 * 60_000L, t.state.value.remainingMs)
        t.skip()
        assertEquals(Phase.BREAK, t.state.value.phase)
        assertEquals(5 * 60_000L, t.state.value.remainingMs)
    }

    @Test
    fun historySplitsAtMidnight() {
        val zone = java.time.ZoneOffset.UTC
        val h = WorkHistory(null, zone = { zone }, today = { java.time.LocalDate.of(2026, 11, 8) })
        val start = java.time.LocalDateTime.of(2026, 11, 7, 23, 30).toInstant(zone).toEpochMilli()
        h.addWork(start, start + 60 * 60_000L)
        assertEquals(1800.0, h.secondsByDay["2026-11-07"]!!, 0.01)
        assertEquals(1800.0, h.secondsByDay["2026-11-08"]!!, 0.01)
    }

    private fun PomodoroTimer.pauseAndRemaining(): Long {
        pause()
        return state.value.remainingMs
    }
}
