package com.example.pawsandponder

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import androidx.core.content.edit
import androidx.core.net.toUri

/** Turns Do Not Disturb on during work and restores the previous setting afterwards. */
class DndController(context: Context) {
    private val nm = context.getSystemService(NotificationManager::class.java)
    private val prefs = context.getSharedPreferences("dnd", Context.MODE_PRIVATE)

    fun setActive(active: Boolean) {
        if (!nm.isNotificationPolicyAccessGranted) return
        val saved = prefs.getInt(KEY_PREVIOUS, NONE)
        if (active) {
            if (saved == NONE) {
                prefs.edit { putInt(KEY_PREVIOUS, nm.currentInterruptionFilter) }
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
        } else if (saved != NONE) {
            // Only restore if nobody changed it since we set it.
            if (nm.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
                nm.setInterruptionFilter(saved)
            }
            prefs.edit { putInt(KEY_PREVIOUS, NONE) }
        }
    }

    companion object {
        private const val KEY_PREVIOUS = "previousFilter"
        private const val NONE = -1

        fun isGranted(context: Context) =
            context.getSystemService(NotificationManager::class.java).isNotificationPolicyAccessGranted

        /** Opens this app's own Do Not Disturb access page, so the app name is shown. */
        fun settingsIntent(context: Context) = Intent(
            "android.settings.NOTIFICATION_POLICY_ACCESS_DETAIL_SETTINGS",
            "package:${context.packageName}".toUri(),
        )
    }
}
