import SwiftUI

/// GitHub-style grid of daily work time: one column per week, one row per weekday.
struct HistoryView: View {
    private struct Day: Identifiable {
        let date: Date
        let seconds: Double
        let column: Int
        let row: Int
        var id: Date { date }
    }

    private static let cellSize: CGFloat = 12
    private static let step: CGFloat = 15 // cell plus a 3 pt gap
    private static let labelColumnWidth: CGFloat = 30
    private static let labelRowHeight: CGFloat = 16

    // Upper bounds, in seconds, of the shaded bands: under 1 h, 1–2 h, 2–4 h, then 4 h or more.
    private static let bandLimits: [Double] = [3600, 7200, 14400]
    private static let bandLabels = ["< 1 h", "1–2 h", "2–4 h", "4 h+"]

    // Each ramp runs from least to most work and was checked for steady lightness steps, one hue,
    // and at least 2:1 contrast between its faintest step and the window background.
    // In dark mode it runs dim to bright, so more work always stands out more.
    private static let lightRamp = [Color(hex: 0x4AB563), Color(hex: 0x2E9E4B), Color(hex: 0x217A3A), Color(hex: 0x155A2A)]
    private static let darkRamp = [Color(hex: 0x2F8A45), Color(hex: 0x36A852), Color(hex: 0x45C763), Color(hex: 0x7BE495)]
    private static let lightEmpty = Color(hex: 0xDCDCDC)
    private static let darkEmpty = Color(hex: 0x444444)

    private let days: [Day]
    private let columnCount: Int
    private let monthLabels: [(column: Int, name: String)]
    private let weekdayLabels: [(row: Int, name: String)]

    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredDay: Day?

    init(secondsByDay: [String: Double]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let earliest = calendar.date(byAdding: .month, value: -WorkHistory.monthsKept, to: today) ?? today
        // The grid starts on the first day of the week containing `earliest`, so rows line up with weekdays.
        let leadingDays = (calendar.component(.weekday, from: earliest) - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: earliest) ?? earliest

        var days: [Day] = []
        var monthLabels: [(column: Int, name: String)] = []
        var index = 0
        var date = gridStart
        while date <= today {
            let column = index / 7
            if date >= earliest {
                days.append(Day(date: date, seconds: secondsByDay[WorkHistory.key(for: date)] ?? 0, column: column, row: index % 7))
                // Label a column with its month when that month starts in it (or the grid starts in it).
                if calendar.component(.day, from: date) == 1 || days.count == 1 {
                    monthLabels.append((column, date.formatted(.dateTime.month(.abbreviated))))
                }
            }
            index += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        self.days = days
        self.columnCount = (index + 6) / 7
        // Drop a first label that would collide with the next one.
        if monthLabels.count > 1, monthLabels[1].column - monthLabels[0].column < 3 {
            monthLabels.removeFirst()
        }
        self.monthLabels = monthLabels

        // Like GitHub, label every other row to keep the column narrow.
        let symbols = calendar.shortWeekdaySymbols
        self.weekdayLabels = [1, 3, 5].map { row in (row, symbols[(calendar.firstWeekday - 1 + row) % 7]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            grid
            legend
        }
        .padding(20)
        .fixedSize()
    }

    // Drawn in one pass instead of as one view per day, to keep memory and layout work low.
    private var grid: some View {
        Canvas { context, _ in
            for day in days {
                context.fill(Path(roundedRect: Self.cellRect(column: day.column, row: day.row), cornerRadius: 2),
                             with: .color(color(for: day.seconds)))
            }
            for label in monthLabels {
                context.draw(Text(label.name).font(.caption2).foregroundStyle(.secondary),
                             at: CGPoint(x: Self.labelColumnWidth + CGFloat(label.column) * Self.step, y: 0),
                             anchor: .topLeading)
            }
            for label in weekdayLabels {
                let rect = Self.cellRect(column: 0, row: label.row)
                context.draw(Text(label.name).font(.caption2).foregroundStyle(.secondary),
                             at: CGPoint(x: 0, y: rect.midY), anchor: .leading)
            }
        }
        .frame(width: Self.labelColumnWidth + CGFloat(columnCount) * Self.step,
               height: Self.labelRowHeight + 7 * Self.step)
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): hoveredDay = day(at: point)
            case .ended: hoveredDay = nil
            }
        }
        .overlay(alignment: .topLeading) {
            if let hoveredDay {
                tooltip(for: hoveredDay)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Work history")
        .accessibilityChildren {
            ForEach(days) { day in
                Text("\(day.date.formatted(date: .complete, time: .omitted)): \(Self.formatDuration(day.seconds))")
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: color(for: 0), label: "No work")
            ForEach(Self.bandLabels.indices, id: \.self) { band in
                legendItem(color: ramp[band], label: Self.bandLabels[band])
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.leading, Self.labelColumnWidth)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: Self.cellSize, height: Self.cellSize)
            Text(label)
        }
    }

    private func tooltip(for day: Day) -> some View {
        let rect = Self.cellRect(column: day.column, row: day.row)
        // Flip to the left of the cell in the right half, so the tooltip stays inside the window.
        let flip = day.column > columnCount / 2
        let text = "\(day.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())) · \(Self.formatDuration(day.seconds))"
        return Text(text)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.background, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
            .fixedSize()
            .alignmentGuide(.leading) { flip ? $0.width - rect.maxX : -rect.minX }
            .alignmentGuide(.top) { $0.height + 4 - rect.minY }
            .allowsHitTesting(false)
    }

    private var ramp: [Color] {
        colorScheme == .dark ? Self.darkRamp : Self.lightRamp
    }

    private func color(for seconds: Double) -> Color {
        guard let band = Self.band(for: seconds) else { return colorScheme == .dark ? Self.darkEmpty : Self.lightEmpty }
        return ramp[band]
    }

    /// Which shaded band a day falls in, from 0 (under an hour) to 3 (4 hours or more); `nil` for no work.
    static func band(for seconds: Double) -> Int? {
        guard seconds > 0 else { return nil }
        return bandLimits.firstIndex { seconds < $0 } ?? bandLimits.count
    }

    /// The day under the pointer. The hit area includes the gap, so it's a little larger than the cell.
    private func day(at point: CGPoint) -> Day? {
        let x = point.x - Self.labelColumnWidth
        let y = point.y - Self.labelRowHeight
        guard x >= 0, y >= 0 else { return nil }
        let column = Int(x / Self.step)
        let row = Int(y / Self.step)
        return days.first { $0.column == column && $0.row == row }
    }

    private static func cellRect(column: Int, row: Int) -> CGRect {
        CGRect(x: labelColumnWidth + CGFloat(column) * step,
               y: labelRowHeight + CGFloat(row) * step,
               width: cellSize, height: cellSize)
    }

    /// Minutes under an hour, hours (to one decimal) from an hour up.
    static func formatDuration(_ seconds: Double) -> String {
        if seconds <= 0 { return "No work" }
        if seconds < 60 { return "Less than 1 min" }
        if seconds < 3600 { return "\(Int((seconds / 60).rounded(.down))) min" }
        let hours = (seconds / 360).rounded() / 10
        return hours == hours.rounded() ? "\(Int(hours)) h" : String(format: "%.1f h", hours)
    }
}

#Preview {
    // Sample data covering every band, including empty days.
    let calendar = Calendar.current
    let samples: [Double] = [0, 900, 0, 4000, 8000, 15000, 2500, 0, 0, 6000, 12000, 20000]
    var secondsByDay: [String: Double] = [:]
    for offset in 0..<120 {
        if let date = calendar.date(byAdding: .day, value: -offset, to: .now) {
            secondsByDay[WorkHistory.key(for: date)] = samples[(offset * 7) % samples.count]
        }
    }
    return HistoryView(secondsByDay: secondsByDay)
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
