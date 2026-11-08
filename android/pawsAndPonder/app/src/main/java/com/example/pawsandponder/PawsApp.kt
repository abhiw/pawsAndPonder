package com.example.pawsandponder

import android.app.Application
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.io.File

/** Owns the timer for the whole process. */
class PawsApp : Application() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    lateinit var settings: Settings
        private set
    lateinit var history: WorkHistory
        private set
    lateinit var timer: PomodoroTimer
        private set
    private lateinit var alerts: PhaseAlerts
    private lateinit var dnd: DndController

    override fun onCreate() {
        super.onCreate()
        settings = Settings(this)
        history = WorkHistory(File(filesDir, "WorkHistory.txt"))
        alerts = PhaseAlerts(this)
        dnd = DndController(this)
        timer = PomodoroTimer(
            scope = scope,
            settings = { settings.value },
            history = history,
            onPhaseFinished = { finished, nextMinutes -> alerts.phaseDidFinish(finished, nextMinutes, settings.value) },
        )

        scope.launch {
            settings.state
                .map { it.workMinutes to it.breakMinutes }
                .distinctUntilChanged()
                .collect { timer.applySettings() }
        }
        // An exact alarm ends the phase on time even in battery saver or Doze.
        val alarm = PhaseEndAlarm(this)
        scope.launch {
            timer.state.map { timer.endElapsedMs }.distinctUntilChanged().collect { alarm.schedule(it) }
        }
        scope.launch {
            combine(timer.state, settings.state) { t, s ->
                s.autoDnd && t.isRunning && t.phase == Phase.WORK
            }.distinctUntilChanged().collect { dnd.setActive(it) }
        }
    }
}
