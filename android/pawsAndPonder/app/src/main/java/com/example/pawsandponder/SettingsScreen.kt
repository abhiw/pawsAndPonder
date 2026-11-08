package com.example.pawsandponder

import android.content.Intent
import android.os.PowerManager
import android.provider.Settings as AndroidSettings
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect

/** Full-screen overlay listing every feature as a row with a toggle, grouped by area. */
@Composable
fun SettingsScreen(settings: Settings, onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    val s by settings.state.collectAsState()
    val context = LocalContext.current

    // Re-read permission state on resume, since it can change in the system settings page.
    var resumes by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { resumes++ }
    val dndGranted = remember(resumes) { DndController.isGranted(context) }
    val unrestricted = remember(resumes) {
        context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName)
    }

    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(Modifier.safeDrawingPadding().verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, bottom = 16.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("Settings", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.weight(1f))
                TextButton(onClick = onClose) { Text("Done") }
            }

            Header("Timer")
            NumberField("Work length (minutes)", s.workMinutes, SettingsData.WORK_RANGE_MIN..SettingsData.WORK_RANGE_MAX) { v -> settings.update { copy(workMinutes = v) } }
            NumberField("Break length (minutes)", s.breakMinutes, SettingsData.BREAK_RANGE_MIN..SettingsData.BREAK_RANGE_MAX) { v -> settings.update { copy(breakMinutes = v) } }
            Toggle("Auto-start break after work", s.autoStartBreak) { v -> settings.update { copy(autoStartBreak = v) } }
            Toggle("Auto-start work after break", s.autoStartWork) { v -> settings.update { copy(autoStartWork = v) } }
            if (!unrestricted) {
                PermissionRow("Battery optimization is on. Some phones may delay alerts.") {
                    context.startActivity(Intent(AndroidSettings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                }
            }

            Header("Display")
            Toggle("Analog clock", s.analog) { v -> settings.update { copy(analog = v) } }
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Theme", Modifier.weight(1f))
                ThemeMode.entries.forEach { mode ->
                    FilterChip(
                        selected = s.theme == mode,
                        onClick = { settings.update { copy(theme = mode) } },
                        label = { Text(mode.name.lowercase().replaceFirstChar { it.uppercase() }) },
                    )
                }
            }

            Header("Alerts")
            Toggle("Sound when a phase ends", s.soundEnabled) { v -> settings.update { copy(soundEnabled = v) } }
            Toggle("Notification when a phase ends", s.notificationsEnabled) { v -> settings.update { copy(notificationsEnabled = v) } }

            Header("Do Not Disturb")
            Toggle("Turn on Do Not Disturb during work", s.autoDnd, if (dndGranted) "Off during breaks; your previous setting is restored" else "Do Not Disturb access not granted") { v -> settings.update { copy(autoDnd = v) } }
            if (s.autoDnd && !dndGranted) {
                PermissionRow("Grant Do Not Disturb access") { context.startActivity(DndController.settingsIntent(context)) }
            }

            Header("History")
            Toggle("Keep work history", s.keepHistory, "Daily work time for the last 4 months") { v -> settings.update { copy(keepHistory = v) } }
        }
    }
}

@Composable
private fun Header(text: String) {
    Text(text, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 20.dp, bottom = 4.dp))
}

@Composable
private fun Toggle(label: String, checked: Boolean, subtitle: String? = null, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(label)
            if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

/** Numeric field typed from the keyboard. The value is applied on Done or when focus leaves, not per keystroke. */
@Composable
private fun NumberField(label: String, value: Int, range: IntRange, onChange: (Int) -> Unit) {
    var text by remember(value) { mutableStateOf(value.toString()) }
    val focus = LocalFocusManager.current
    fun commit() {
        val v = text.toIntOrNull()?.coerceIn(range.first, range.last) ?: value
        text = v.toString()
        if (v != value) onChange(v)
    }
    OutlinedTextField(
        value = text,
        onValueChange = { text = it.filter(Char::isDigit).take(3) },
        label = { Text(label) },
        supportingText = { Text("${range.first}–${range.last}") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { commit(); focus.clearFocus() }),
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).onFocusChanged { if (!it.isFocused) commit() },
    )
}

@Composable
private fun PermissionRow(label: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
        TextButton(onClick = onClick) { Text("Open settings") }
    }
}
