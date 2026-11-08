package com.example.pawsandponder

import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Work time per day for the last few months, saved as lines of "yyyy-MM-dd=seconds".
 * Keys are ISO dates, so comparing them as strings compares the dates.
 */
class WorkHistory(
    private val file: File?,
    private val zone: () -> ZoneId = { ZoneId.systemDefault() },
    private val today: () -> LocalDate = { LocalDate.now() },
) {
    private val days: MutableMap<String, Double> by lazy { load() }

    val secondsByDay: Map<String, Double> get() = days.toMap()

    /** Adds a stretch of work, split at midnight so each day gets its own share. */
    fun addWork(startMillis: Long, endMillis: Long) {
        val z = zone()
        var segmentStart = Instant.ofEpochMilli(startMillis).atZone(z)
        val end = Instant.ofEpochMilli(endMillis).atZone(z)
        while (segmentStart < end) {
            val nextMidnight = segmentStart.toLocalDate().plusDays(1).atStartOfDay(z)
            val segmentEnd = if (end < nextMidnight) end else nextMidnight
            if (segmentEnd <= segmentStart) break
            val seconds = (segmentEnd.toInstant().toEpochMilli() - segmentStart.toInstant().toEpochMilli()) / 1000.0
            val key = segmentStart.toLocalDate().toString()
            days[key] = (days[key] ?: 0.0) + seconds
            segmentStart = segmentEnd
        }
        prune()
        save()
    }

    private val cutoffKey: String get() = today().minusMonths(MONTHS_KEPT.toLong()).toString()

    private fun prune() {
        val cutoff = cutoffKey
        days.keys.removeAll { it < cutoff }
    }

    private fun load(): MutableMap<String, Double> {
        val map = mutableMapOf<String, Double>()
        val f = file ?: return map
        if (!f.exists()) return map
        val cutoff = cutoffKey
        runCatching {
            f.readLines().forEach { line ->
                val parts = line.split("=")
                val seconds = parts.getOrNull(1)?.toDoubleOrNull()
                if (parts.size == 2 && seconds != null && parts[0] >= cutoff) map[parts[0]] = seconds
            }
        }
        return map
    }

    private fun save() {
        val f = file ?: return
        // History is a convenience; if saving fails the timer keeps working.
        runCatching {
            f.parentFile?.mkdirs()
            val tmp = File(f.path + ".tmp")
            tmp.writeText(days.entries.joinToString("\n") { "${it.key}=${it.value}" })
            if (!tmp.renameTo(f)) f.writeText(tmp.readText())
        }
    }

    companion object {
        const val MONTHS_KEPT = 4

        /** Minutes under an hour, hours (to one decimal) from an hour up. */
        fun formatDuration(seconds: Double): String {
            if (seconds <= 0) return "No work"
            if (seconds < 60) return "Less than 1 min"
            if (seconds < 3600) return "${(seconds / 60).toInt()} min"
            val hours = Math.round(seconds / 360.0) / 10.0
            return if (hours == Math.rint(hours)) "${hours.toInt()} h" else String.format("%.1f h", hours)
        }

        private val bandLimits = listOf(3600.0, 7200.0, 14400.0)

        /** Shaded band from 0 (under an hour) to 3 (4 hours or more); null for no work. */
        fun band(seconds: Double): Int? {
            if (seconds <= 0) return null
            return bandLimits.indexOfFirst { seconds < it }.let { if (it == -1) bandLimits.size else it }
        }
    }
}
