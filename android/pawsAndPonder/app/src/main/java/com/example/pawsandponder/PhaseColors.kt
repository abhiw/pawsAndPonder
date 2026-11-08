package com.example.pawsandponder

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance

// Timer colours from the Mac app. The rest of the UI uses the system theme.
private val workLight = Color(0xFF34C759)
private val workDark = Color(0xFF30D158)
private val breakLight = Color(0xFF007AFF)
private val breakDark = Color(0xFF0A84FF)

/** Green while working, blue on a break. */
@Composable
fun Phase.color(): Color {
    val dark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    return when (this) {
        Phase.WORK -> if (dark) workDark else workLight
        Phase.BREAK -> if (dark) breakDark else breakLight
    }
}
