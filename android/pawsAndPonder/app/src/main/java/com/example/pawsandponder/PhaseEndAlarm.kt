package com.example.pawsandponder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock

/**
 * Exact alarm for the end of the running phase. Coroutine delays stop while the CPU sleeps, so in battery
 * saver or Doze the phase-end tick could come late; this alarm wakes the device on time instead.
 */
class PhaseEndAlarm(private val context: Context) {
    private val alarmManager = context.getSystemService(AlarmManager::class.java)

    private fun pendingIntent() = PendingIntent.getBroadcast(
        context, 0,
        Intent(context, Receiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** Schedules the alarm for [endElapsedMs] on the elapsedRealtime clock, or cancels it when null. */
    fun schedule(endElapsedMs: Long?) {
        if (endElapsedMs == null) {
            alarmManager.cancel(pendingIntent())
            return
        }
        val trigger = maxOf(endElapsedMs, SystemClock.elapsedRealtime()) + 20
        runCatching {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, trigger, pendingIntent())
        }
    }

    class Receiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            (context.applicationContext as PawsApp).timer.tick()
        }
    }
}
