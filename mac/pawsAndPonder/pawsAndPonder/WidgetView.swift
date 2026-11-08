import SwiftUI

/// Compact countdown with controls, shown in the floating panel.
struct WidgetView: View {
    let timer: PomodoroTimer

    @AppStorage(SettingsKey.displayStyle) private var displayStyle = SettingsDefault.displayStyle
    @AppStorage(SettingsKey.barWidth) private var barWidth = SettingsDefault.barWidth

    // Mouse position and bar width when a resize drag began.
    @State private var resizeStart: (mouseX: Double, width: Double)?

    /// Allowed widths of the time area in bar mode.
    static let barWidthRange: ClosedRange<Double> = 80...400

    /// Width of the time area. The panel controller uses this too, so it can size the panel without
    /// waiting for the view to re-render.
    static func timeAreaWidth(style: TimerDisplayStyle, barWidth: Double) -> CGFloat {
        switch style {
        case .digital: 104
        case .bar: CGFloat(min(max(barWidth, barWidthRange.lowerBound), barWidthRange.upperBound))
        }
    }

    // Only the time area reads the remaining time, so each tick redraws just that part.
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(timer.phase.color)
                .frame(width: 8, height: 8)

            Group {
                switch displayStyle {
                case .digital: DigitalTime(timer: timer)
                case .bar: ProgressBar(timer: timer)
                }
            }
            .frame(width: Self.timeAreaWidth(style: displayStyle, barWidth: barWidth), alignment: .leading)

            controls
                .padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        // Solid rather than a material, so the system doesn't keep re-blurring what's behind the widget.
        .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
        .contentShape(Capsule())
        .gesture(
            // The hosting view swallows mouse events, so background-dragging doesn't work on its
            // own. The event's window is the panel, so hand the drag to the system from here.
            DragGesture(minimumDistance: 3)
                .onChanged { _ in
                    guard let event = NSApp.currentEvent, let window = event.window else { return }
                    window.performDrag(with: event)
                }
        )
        .overlay(alignment: .trailing) {
            if displayStyle == .bar {
                resizeHandle
            }
        }
        .fixedSize()
    }

    private var controls: some View {
        HStack(spacing: 10) {
            controlButton(timer.isRunning ? "pause.fill" : "play.fill",
                          label: timer.isRunning ? "Pause" : "Start") {
                timer.toggle()
            }
            controlButton("arrow.counterclockwise", label: "Reset") {
                timer.reset()
            }
            controlButton("forward.end.fill", label: "Skip to \(timer.phase.next.title)") {
                timer.skip()
            }
        }
    }

    /// Grip on the right edge. Dragging it changes the bar length; the panel follows the setting.
    private var resizeHandle: some View {
        Capsule()
            .fill(.secondary.opacity(0.6))
            .frame(width: 3, height: 14)
            .frame(width: 12, height: 32)
            .contentShape(Rectangle())
            .padding(.trailing, 2)
            .help("Drag to change the bar length")
            .accessibilityHidden(true)
            .highPriorityGesture(
                // The widget moves under the cursor while resizing, so track the screen position
                // of the mouse instead of the gesture's own translation.
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in
                        let mouseX = Double(NSEvent.mouseLocation.x)
                        let start = resizeStart ?? (mouseX: mouseX, width: barWidth)
                        resizeStart = start
                        let proposed = start.width + (mouseX - start.mouseX)
                        barWidth = min(max(proposed, Self.barWidthRange.lowerBound), Self.barWidthRange.upperBound)
                    }
                    .onEnded { _ in
                        resizeStart = nil
                    }
            )
    }

    private func controlButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

private extension PomodoroTimer.Phase {
    var color: Color {
        self == .work ? .green : .blue
    }
}

private struct DigitalTime: View {
    let timer: PomodoroTimer

    var body: some View {
        HStack(spacing: 8) {
            Text(timer.formattedRemaining)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text(timer.phase.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Fills left to right as the phase approaches completion, next to the phase's configured length.
private struct ProgressBar: View {
    let timer: PomodoroTimer

    var body: some View {
        let minutes = Int(timer.phaseDuration / 60)

        HStack(spacing: 6) {
            Capsule()
                .fill(.quaternary)
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(timer.phase.color)
                            .frame(width: proxy.size.width * timer.progress)
                    }
                }

            // The set length, not the time left, so it doesn't change as the phase progresses.
            Text("\(minutes) min")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .help("\(timer.phase.title): \(timer.formattedRemaining) left")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timer.phase.title) progress, \(minutes) minutes")
        .accessibilityValue("\(timer.formattedRemaining) left")
    }
}
