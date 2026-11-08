package com.example.pawsandponder

import android.content.Context
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class ThemeMode { SYSTEM, LIGHT, DARK }

data class SettingsData(
    val workMinutes: Int = 25,
    val breakMinutes: Int = 5,
    val autoStartBreak: Boolean = true,
    val autoStartWork: Boolean = false,
    val analog: Boolean = false,
    val theme: ThemeMode = ThemeMode.SYSTEM,
    val soundEnabled: Boolean = true,
    val notificationsEnabled: Boolean = true,
    val autoDnd: Boolean = false,
    val keepHistory: Boolean = false,
) {
    companion object {
        const val WORK_RANGE_MIN = 1
        const val WORK_RANGE_MAX = 180
        const val BREAK_RANGE_MIN = 1
        const val BREAK_RANGE_MAX = 60
    }
}

/** Settings persisted in SharedPreferences and exposed as a flow. */
class Settings(context: Context) {
    private val prefs = context.getSharedPreferences("settings", Context.MODE_PRIVATE)
    private val _state = MutableStateFlow(load())
    val state: StateFlow<SettingsData> = _state

    val value: SettingsData get() = _state.value

    fun update(change: SettingsData.() -> SettingsData) {
        val new = _state.value.change().let {
            it.copy(
                workMinutes = it.workMinutes.coerceIn(SettingsData.WORK_RANGE_MIN, SettingsData.WORK_RANGE_MAX),
                breakMinutes = it.breakMinutes.coerceIn(SettingsData.BREAK_RANGE_MIN, SettingsData.BREAK_RANGE_MAX),
            )
        }
        _state.value = new
        prefs.edit {
            putInt("workMinutes", new.workMinutes)
            putInt("breakMinutes", new.breakMinutes)
            putBoolean("autoStartBreak", new.autoStartBreak)
            putBoolean("autoStartWork", new.autoStartWork)
            putBoolean("analog", new.analog)
            putString("theme", new.theme.name)
            putBoolean("soundEnabled", new.soundEnabled)
            putBoolean("notificationsEnabled", new.notificationsEnabled)
            putBoolean("autoDnd", new.autoDnd)
            putBoolean("keepHistory", new.keepHistory)
        }
    }

    private fun load(): SettingsData {
        val d = SettingsData()
        return SettingsData(
            workMinutes = prefs.getInt("workMinutes", d.workMinutes),
            breakMinutes = prefs.getInt("breakMinutes", d.breakMinutes),
            autoStartBreak = prefs.getBoolean("autoStartBreak", d.autoStartBreak),
            autoStartWork = prefs.getBoolean("autoStartWork", d.autoStartWork),
            analog = prefs.getBoolean("analog", d.analog),
            theme = prefs.getString("theme", null).let { name -> ThemeMode.entries.find { it.name == name } } ?: d.theme,
            soundEnabled = prefs.getBoolean("soundEnabled", d.soundEnabled),
            notificationsEnabled = prefs.getBoolean("notificationsEnabled", d.notificationsEnabled),
            autoDnd = prefs.getBoolean("autoDnd", d.autoDnd),
            keepHistory = prefs.getBoolean("keepHistory", d.keepHistory),
        )
    }
}
