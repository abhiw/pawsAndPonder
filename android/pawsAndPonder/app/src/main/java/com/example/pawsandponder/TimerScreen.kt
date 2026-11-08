package com.example.pawsandponder

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

private const val CONTROLS_HIDE_AFTER_MS = 4000L

/**
 * Full-screen timer. The clock fills the screen in portrait and landscape. The Start/Pause, Reset and
 * Skip buttons stay hidden until you tap the screen, then hide again after a few seconds.
 */
@Composable
fun TimerScreen(
    timer: PomodoroTimer,
    settings: SettingsData,
    onOpenSettings: () -> Unit,
    onOpenHistory: () -> Unit,
) {
    val state by timer.state.collectAsState()
    var controlsVisible by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(controlsVisible, state.isRunning, state.phase) {
        if (controlsVisible) {
            delay(CONTROLS_HIDE_AFTER_MS)
            controlsVisible = false
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        BoxWithConstraints(
            Modifier
                .fillMaxSize()
                .safeDrawingPadding()
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                    controlsVisible = !controlsVisible
                },
        ) {
            val landscape = maxWidth > maxHeight

            // Portrait leaves a strip on top for the phase name; landscape puts it in the corner.
            Box(
                Modifier
                    .fillMaxSize()
                    .padding(start = 16.dp, end = 16.dp, bottom = 16.dp, top = if (landscape) 8.dp else 64.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (settings.analog) AnalogClock(timer, state) else DigitalClock(state)
            }

            Text(
                state.phase.title,
                style = MaterialTheme.typography.headlineMedium,
                color = state.phase.color(),
                modifier = Modifier
                    .align(if (landscape) Alignment.TopStart else Alignment.TopCenter)
                    .padding(top = 12.dp, start = if (landscape) 20.dp else 0.dp),
            )

            Row(Modifier.align(Alignment.TopEnd)) {
                if (settings.keepHistory) TextButton(onClick = onOpenHistory) { Text("History") }
                IconButton(onClick = onOpenSettings) { Icon(painterResource(R.drawable.ic_settings), contentDescription = "Settings") }
            }

            AnimatedVisibility(
                visible = controlsVisible,
                enter = fadeIn(),
                exit = fadeOut(),
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp),
            ) {
                Surface(shape = RoundedCornerShape(50), color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.92f)) {
                    Row(
                        Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Button(
                            onClick = timer::toggle,
                            colors = ButtonDefaults.buttonColors(containerColor = state.phase.color(), contentColor = Color.White),
                        ) { Text(if (state.isRunning) "Pause" else "Start") }
                        FilledTonalButton(onClick = timer::reset) { Text("Reset") }
                        OutlinedButton(onClick = timer::skip) { Text("Skip") }
                    }
                }
            }
        }
    }
}

@Composable
private fun DigitalClock(state: TimerState) {
    BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        // "00:00" in a monospace font is about 3 em wide.
        val size: Dp = minOf(maxWidth / 3.2f, maxHeight * 0.85f)
        Text(
            text = state.formatted,
            fontSize = size.value.sp,
            fontWeight = FontWeight.Light,
            fontFamily = FontFamily.Monospace,
            maxLines = 1,
            softWrap = false,
            color = MaterialTheme.colorScheme.onBackground,
        )
    }
}

@Composable
private fun AnalogClock(timer: PomodoroTimer, state: TimerState) {
    // Follows the frame clock between ticks so the hand sweeps smoothly. Read only in the draw
    // phase below, so each frame redraws the dial without recomposing.
    var remainingMs by remember { mutableLongStateOf(state.remainingMs) }
    LaunchedEffect(state) {
        remainingMs = state.remainingMs
        if (state.isRunning) {
            while (true) {
                withFrameMillis { }
                remainingMs = timer.remainingNow()
            }
        }
    }
    val durationMs = state.phaseDurationMs

    val ring = state.phase.color()
    val track = MaterialTheme.colorScheme.surfaceVariant
    val face = MaterialTheme.colorScheme.surfaceContainer
    val tick = MaterialTheme.colorScheme.onSurfaceVariant
    val hand = MaterialTheme.colorScheme.onBackground

    BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        val side: Dp = minOf(maxWidth, maxHeight)
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(side)) {
            Canvas(Modifier.fillMaxSize()) {
                val progress = (1f - remainingMs.toFloat() / durationMs).coerceIn(0f, 1f)
                val stroke = size.minDimension * 0.04f
                val radius = size.minDimension / 2 - stroke
                val center = Offset(size.width / 2, size.height / 2)
                drawCircle(face, radius = radius)
                // Ring: the elapsed part of the phase fills clockwise from 12 o'clock.
                val topLeft = Offset(center.x - radius, center.y - radius)
                drawArc(track, 0f, 360f, false, topLeft, Size(radius * 2, radius * 2), style = Stroke(stroke))
                drawArc(ring, -90f, 360f * progress, false, topLeft, Size(radius * 2, radius * 2), style = Stroke(stroke, cap = StrokeCap.Round))
                for (i in 0 until 12) {
                    val a = i * PI / 6
                    val inner = radius - stroke - size.minDimension * 0.04f
                    val outer = radius - stroke - size.minDimension * 0.01f
                    drawLine(
                        tick,
                        Offset(center.x + (inner * sin(a)).toFloat(), center.y - (inner * cos(a)).toFloat()),
                        Offset(center.x + (outer * sin(a)).toFloat(), center.y - (outer * cos(a)).toFloat()),
                        strokeWidth = 2.dp.toPx(), cap = StrokeCap.Round,
                    )
                }
                val angle = 2 * PI * progress
                val handLen = radius - stroke - size.minDimension * 0.08f
                drawLine(
                    hand, center,
                    Offset(center.x + (handLen * sin(angle)).toFloat(), center.y - (handLen * cos(angle)).toFloat()),
                    strokeWidth = 4.dp.toPx(), cap = StrokeCap.Round,
                )
                drawCircle(hand, radius = 6.dp.toPx(), center = center)
            }
            Text(
                state.formatted,
                fontSize = (side.value * 0.075f).sp,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = side * 0.35f),
            )
        }
    }
}
