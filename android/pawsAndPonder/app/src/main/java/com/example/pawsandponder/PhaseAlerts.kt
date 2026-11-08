package com.example.pawsandponder

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Sound and notification shown when a phase ends, each with its own toggle.
 * The sound is a short chime played a couple of times, and respects Do Not Disturb.
 */
class PhaseAlerts(private val context: Context) {
    private val nm = context.getSystemService(NotificationManager::class.java)
    private val handler = Handler(Looper.getMainLooper())

    fun phaseDidFinish(finished: Phase, nextMinutes: Int, s: SettingsData) {
        if (s.notificationsEnabled) {
            val (title, body) = when (finished) {
                Phase.WORK -> "Work session finished" to "Time for a $nextMinutes minute break."
                Phase.BREAK -> "Break is over" to "Ready for a $nextMinutes minute work session."
            }
            val open = PendingIntent.getActivity(
                context, 0,
                // Bring back the existing timer screen instead of stacking a new one.
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val builder = NotificationCompat.Builder(context, ensureChannel())
                .setSmallIcon(R.drawable.ic_paw)
                .setContentTitle(title)
                .setContentText(body)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(open)
            runCatching { nm.notify(ALERT_ID, builder.build()) }
        }
        if (s.soundEnabled) chime()
    }

    // The notification itself is silent; the chime is played here so it is short and repeated only twice.
    private fun ensureChannel(): String {
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Phase end", NotificationManager.IMPORTANCE_HIGH).apply {
                    setSound(null, null)
                    enableVibration(false)
                }
            )
        }
        return CHANNEL_ID
    }

    private fun chime() {
        repeat(CHIME_COUNT) { i -> handler.postDelayed({ playOnce() }, i * CHIME_GAP_MS) }
    }

    private fun playOnce() {
        runCatching {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            RingtoneManager.getRingtone(context, uri)?.apply {
                audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }?.play()
        }
    }

    companion object {
        private const val ALERT_ID = 2
        private const val CHANNEL_ID = "phase_end"
        private const val CHIME_COUNT = 2
        private const val CHIME_GAP_MS = 1500L
    }
}
