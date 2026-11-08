package com.example.pawsandponder

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import java.time.format.TextStyle as MonthStyle
import androidx.compose.ui.unit.dp
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.WeekFields
import java.util.Locale

private data class Day(val date: LocalDate, val seconds: Double, val column: Int, val row: Int)

private val lightRamp = listOf(Color(0xFF4AB563), Color(0xFF2E9E4B), Color(0xFF217A3A), Color(0xFF155A2A))
private val darkRamp = listOf(Color(0xFF2F8A45), Color(0xFF36A852), Color(0xFF45C763), Color(0xFF7BE495))
private val bandLabels = listOf("< 1 h", "1–2 h", "2–4 h", "4 h+")
private val LABEL_ROW = 18.dp

/** GitHub-style grid of daily work time: one column per week, one row per weekday. Tap a day for details. */
@Composable
fun HistoryScreen(history: WorkHistory, onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    // Follow the app theme setting, not only the system one.
    val dark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val ramp = if (dark) darkRamp else lightRamp
    val empty = if (dark) Color(0xFF444444) else Color(0xFFDCDCDC)

    val (days, columns, monthLabels) = remember(history) {
        val data = history.secondsByDay
        val today = LocalDate.now()
        val earliest = today.minusMonths(WorkHistory.MONTHS_KEPT.toLong())
        val first: DayOfWeek = WeekFields.of(Locale.getDefault()).firstDayOfWeek
        val leading = (earliest.dayOfWeek.value - first.value + 7) % 7
        val list = mutableListOf<Day>()
        val labels = mutableListOf<Pair<Int, String>>()
        var index = 0
        var date = earliest.minusDays(leading.toLong())
        while (!date.isAfter(today)) {
            if (!date.isBefore(earliest)) {
                // Label a column with its month when that month starts in it (or the grid starts in it).
                if (date.dayOfMonth == 1 || list.isEmpty()) {
                    labels += (index / 7) to date.month.getDisplayName(MonthStyle.SHORT, Locale.getDefault())
                }
                list += Day(date, data[date.toString()] ?: 0.0, index / 7, index % 7)
            }
            index++
            date = date.plusDays(1)
        }
        // Drop a first label that would collide with the next one.
        if (labels.size > 1 && labels[1].first - labels[0].first < 3) labels.removeAt(0)
        Triple(list, (index + 6) / 7, labels.toList())
    }
    val measurer = rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val outline = MaterialTheme.colorScheme.onBackground
    var selected by remember { mutableStateOf<Day?>(null) }

    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(Modifier.safeDrawingPadding().padding(horizontal = 20.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("Work history", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.weight(1f))
                TextButton(onClick = onClose) { Text("Done") }
            }
            val gap = with(LocalDensity.current) { 3.dp.toPx() }
            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp)
                    .height(240.dp)
                    .pointerInput(columns) {
                        detectTapGestures { p ->
                            val step = size.width.toFloat() / columns
                            val y = p.y - LABEL_ROW.toPx()
                            if (y < 0) return@detectTapGestures
                            val col = (p.x / step).toInt()
                            val row = (y / step).toInt()
                            selected = days.firstOrNull { it.column == col && it.row == row }
                        }
                    },
            ) {
                Canvas(Modifier.fillMaxSize()) {
                    val step = size.width / columns
                    val top = LABEL_ROW.toPx()
                    monthLabels.forEach { (col, name) ->
                        drawText(measurer, name, Offset(col * step, 0f), labelStyle)
                    }
                    days.forEach { d ->
                        val color = WorkHistory.band(d.seconds)?.let { ramp[it] } ?: empty
                        drawRoundRect(
                            color,
                            Offset(d.column * step, top + d.row * step),
                            Size(step - gap, step - gap),
                            CornerRadius(3.dp.toPx()),
                        )
                        if (d == selected) {
                            drawRoundRect(
                                outline, Offset(d.column * step, top + d.row * step), Size(step - gap, step - gap),
                                CornerRadius(3.dp.toPx()),
                                style = Stroke(2.dp.toPx()),
                            )
                        }
                    }
                }
            }
            Text(
                selected?.let {
                    "${it.date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))} · ${WorkHistory.formatDuration(it.seconds)}"
                } ?: "Tap a day for details",
                modifier = Modifier.padding(vertical = 12.dp),
                style = MaterialTheme.typography.bodyLarge,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                Legend(empty, "None")
                bandLabels.forEachIndexed { i, label -> Legend(ramp[i], label) }
            }
        }
    }
}

@Composable
private fun Legend(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Canvas(Modifier.size(12.dp)) { drawRoundRect(color, cornerRadius = CornerRadius(2.dp.toPx())) }
        Text(label, Modifier.padding(start = 4.dp), style = MaterialTheme.typography.labelSmall)
    }
}
