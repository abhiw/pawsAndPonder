package com.example.pawsandponder

import android.os.SystemClock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlin.math.ceil

enum class Phase(val title: String) {
    WORK("Work"), BREAK("Break");

    val next: Phase get() = if (this == WORK) BREAK else WORK
}

data class TimerState(
    val phase: Phase = Phase.WORK,
    val remainingMs: Long = 0,
    val isRunning: Boolean = false,
    /** Length of the current phase as loaded, so progress stays right if settings change mid-phase. */
    val phaseDurationMs: Long = 1,
) {
    /** mm:ss, rounded up so the display hits 00:00 only at the end. */
    val formatted: String
        get() {
            val seconds = ceil(remainingMs / 1000.0).toInt()
            return "%02d:%02d".format(seconds / 60, seconds % 60)
        }
}

/**
 * Work/break timer. Time is derived from an end timestamp on a monotonic clock rather than
 * counting ticks, so it stays accurate through Doze and delayed callbacks. All calls on one thread (Main).
 */
class PomodoroTimer(
    private val scope: CoroutineScope,
    private val settings: () -> SettingsData,
    private val history: WorkHistory,
    private val monotonicMs: () -> Long = { SystemClock.elapsedRealtime() },
    private val wallMs: () -> Long = { System.currentTimeMillis() },
    private val onPhaseFinished: (finished: Phase, nextMinutes: Int) -> Unit = { _, _ -> },
) {
    private val _state = MutableStateFlow(TimerState())
    val state: StateFlow<TimerState> = _state

    private var endMs: Long? = null
    private var tickJob: Job? = null
    private var workRunStartWall: Long? = null

    private var phase = Phase.WORK
    private var remainingMs = 0L
    private var phaseDurationMs = 1L
    private var running = false

    init {
        loadPhase()
        publish()
    }

    /** When the running phase ends, on the monotonic clock; null while paused. */
    val endElapsedMs: Long? get() = endMs

    /** Remaining time right now, for smooth animation between ticks. */
    fun remainingNow(): Long = endMs?.let { (it - monotonicMs()).coerceAtLeast(0) } ?: remainingMs

    fun start() {
        if (running) return
        endMs = monotonicMs() + remainingMs
        running = true
        workRunStartWall = if (phase == Phase.WORK) wallMs() else null
        startTicking()
        publish()
    }

    fun pause() {
        val end = endMs ?: return
        if (!running) return
        remainingMs = (end - monotonicMs()).coerceAtLeast(0)
        stopTicking()
        publish()
    }

    fun toggle() = if (running) pause() else start()

    /** Records the work time of a running phase so far, for example before the app closes. */
    fun recordProgress() {
        if (!running) return
        recordWorkRun()
        workRunStartWall = if (phase == Phase.WORK) wallMs() else null
    }

    /** Stops the timer and restores the full duration of the current phase. */
    fun reset() {
        stopTicking()
        loadPhase()
        publish()
    }

    /**
     * Call when the durations change. The current phase switches to its new length right away and
     * keeps the time already elapsed. If more time has elapsed than the new length, the phase ends.
     */
    fun applySettings() {
        val newDuration = durationOf(phase)
        if (newDuration == phaseDurationMs) return

        endMs?.let { remainingMs = (it - monotonicMs()).coerceAtLeast(0) }
        val elapsed = phaseDurationMs - remainingMs
        phaseDurationMs = newDuration
        remainingMs = (phaseDurationMs - elapsed).coerceAtLeast(0)

        if (remainingMs == 0L) {
            completePhase()
        } else if (running) {
            endMs = monotonicMs() + remainingMs
            startTicking()
        }
        publish()
    }

    /** Moves to the other phase, staying paused or running as before. */
    fun skip() {
        val wasRunning = running
        stopTicking()
        phase = phase.next
        loadPhase()
        if (wasRunning) start()
        publish()
    }

    /** Brings the remaining time up to date and ends the phase when time is up. */
    fun tick() {
        val end = endMs ?: return
        remainingMs = (end - monotonicMs()).coerceAtLeast(0)
        if (remainingMs == 0L) completePhase()
        publish()
    }

    private fun publish() {
        _state.value = TimerState(phase, remainingMs, running, phaseDurationMs)
    }

    private fun loadPhase() {
        phaseDurationMs = durationOf(phase)
        remainingMs = phaseDurationMs
    }

    private fun durationOf(phase: Phase): Long {
        val s = settings()
        val minutes = if (phase == Phase.WORK) s.workMinutes else s.breakMinutes
        return maxOf(1, minutes) * 60_000L
    }

    private fun startTicking() {
        tickJob?.cancel()
        tickJob = scope.launch {
            while (true) {
                // Wake just after the displayed second changes instead of polling.
                val remaining = (endMs ?: return@launch) - monotonicMs()
                val intoSecond = remaining % 1000
                delay(if (intoSecond <= 0) 1010L else intoSecond + 10)
                tick()
            }
        }
    }

    /** Every way of stopping (pause, reset, skip, phase end) comes through here. */
    private fun stopTicking() {
        recordWorkRun()
        tickJob?.cancel()
        tickJob = null
        endMs = null
        running = false
    }

    private fun recordWorkRun() {
        val start = workRunStartWall ?: return
        workRunStartWall = null
        if (!settings().keepHistory) return
        // A late tick mustn't count time past the end of the phase.
        val wallNow = wallMs()
        val late = endMs?.let { (monotonicMs() - it).coerceAtLeast(0) } ?: 0L
        val end = wallNow - late
        if (end > start) history.addWork(start, end)
    }

    private fun completePhase() {
        val finished = phase
        stopTicking()
        phase = finished.next
        loadPhase()
        onPhaseFinished(finished, (remainingMs / 60_000).toInt())

        val s = settings()
        if (if (finished == Phase.WORK) s.autoStartBreak else s.autoStartWork) start()
    }
}
