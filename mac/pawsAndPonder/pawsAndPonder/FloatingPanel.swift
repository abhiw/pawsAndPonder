import AppKit
import SwiftUI

/// Borderless panel that never takes focus, so clicking it doesn't pull you out of the app you're using.
final class FloatingPanel: NSPanel, NSWindowDelegate {
    /// Called after the user moves the panel.
    var onMove: (() -> Void)?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        delegate = self
    }

    func windowDidMove(_ notification: Notification) {
        onMove?()
    }
}

private extension NSScreen {
    /// Stable identifier of the physical display.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// Keeps one always-on-top widget on the primary display, or on every display if the setting is on.
final class FloatingPanelController {
    private let timer: PomodoroTimer
    private let margin: CGFloat = 16
    private var panels: [CGDirectDisplayID: FloatingPanel] = [:]
    private var observers: [Task<Void, Never>] = []
    // Panel width minus the time area: the part of the widget that never changes size.
    private var fixedWidth: CGFloat = 0

    init(timer: PomodoroTimer) {
        self.timer = timer
        updatePanels()

        // Re-sync when settings change, and when displays are plugged in, unplugged or rearranged.
        observers = [
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
                    self?.updatePanels()
                }
            },
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
                    self?.repositionPanels()
                    self?.updatePanels()
                }
            }
        ]
    }

    deinit {
        observers.forEach { $0.cancel() }
    }

    /// Adds and removes panels so they match the displays that should show the widget, then sizes them.
    private func updatePanels() {
        // The first screen is the primary display, the one with the menu bar.
        let screens = NSScreen.screens
        let showOnAll = UserDefaults.standard.bool(forKey: SettingsKey.showOnAllDisplays)
        let wanted = showOnAll ? screens : Array(screens.prefix(1))
        let wantedIDs = Set(wanted.compactMap(\.displayID))

        for (id, panel) in panels where !wantedIDs.contains(id) {
            panel.onMove = nil
            panel.orderOut(nil)
            panels[id] = nil
        }

        for screen in wanted {
            guard let id = screen.displayID, panels[id] == nil else { continue }
            let panel = makePanel(for: screen, id: id)
            panels[id] = panel
            panel.orderFrontRegardless()
        }

        resizePanels()
        applyTheme()
    }

    /// Light or dark appearance for every panel; `nil` follows the system setting.
    private func applyTheme() {
        let rawTheme = UserDefaults.standard.string(forKey: SettingsKey.widgetTheme) ?? ""
        let appearance: NSAppearance? = switch WidgetTheme(rawValue: rawTheme) ?? SettingsDefault.widgetTheme {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
        for panel in panels.values where panel.appearance != appearance {
            panel.appearance = appearance
        }
    }

    private var timeAreaWidth: CGFloat {
        let defaults = UserDefaults.standard
        let style = TimerDisplayStyle(rawValue: defaults.string(forKey: SettingsKey.displayStyle) ?? "")
        return WidgetView.timeAreaWidth(
            style: style ?? SettingsDefault.displayStyle,
            barWidth: defaults.double(forKey: SettingsKey.barWidth)
        )
    }

    /// Matches every panel to the current width, keeping its position and height.
    private func resizePanels() {
        let width = fixedWidth + timeAreaWidth
        for panel in panels.values where abs(panel.frame.width - width) > 0.5 {
            var frame = panel.frame
            frame.size.width = width
            panel.setFrame(frame, display: true)
        }
    }

    private func makePanel(for screen: NSScreen, id: CGDirectDisplayID) -> FloatingPanel {
        let hostingView = NSHostingView(rootView: WidgetView(timer: timer))
        let size = hostingView.fittingSize
        fixedWidth = size.width - timeAreaWidth

        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.level = .floating
        // Visible on every Space, including over full-screen apps.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        position(panel, on: screen, id: id)

        // Set after positioning, so only moves made by the user are saved.
        panel.onMove = { [weak self, weak panel] in
            guard let self, let panel else { return }
            savePosition(of: panel, onDisplay: id)
        }
        return panel
    }

    /// Puts a panel at its saved spot on the display, or in the top-right corner if it has none.
    private func position(_ panel: FloatingPanel, on screen: NSScreen, id: CGDirectDisplayID) {
        let area = screen.visibleFrame
        if let offset = savedOffset(forDisplay: id) {
            panel.setFrameOrigin(NSPoint(
                x: area.minX + offset.x,
                y: area.maxY - offset.y - panel.frame.height
            ))
            if area.intersects(panel.frame) { return }
        }
        // No saved spot, or a stale one, for example after the display got smaller.
        panel.setFrameOrigin(NSPoint(
            x: area.maxX - panel.frame.width - margin,
            y: area.maxY - panel.frame.height - margin
        ))
    }

    /// Re-places every widget after the display layout changed, since moved or resized displays
    /// would otherwise leave the panels at their old screen coordinates.
    private func repositionPanels() {
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let panel = panels[id] else { continue }
            // Re-placing isn't a user move, so it shouldn't be saved as one.
            let onMove = panel.onMove
            panel.onMove = nil
            position(panel, on: screen, id: id)
            panel.onMove = onMove
        }
    }

    // MARK: - Saved positions

    // Stored per display as the distance from the top-left corner of its usable area.
    // Unlike AppKit's frame autosave, this can't put a widget on the wrong display.
    private let offsetsKey = "widgetOffsets"

    private var savedOffsets: [String: [Double]] {
        UserDefaults.standard.dictionary(forKey: offsetsKey) as? [String: [Double]] ?? [:]
    }

    private func savedOffset(forDisplay id: CGDirectDisplayID) -> CGPoint? {
        guard let stored = savedOffsets[String(id)], stored.count == 2 else { return nil }
        return CGPoint(x: stored[0], y: stored[1])
    }

    private func savePosition(of panel: FloatingPanel, onDisplay id: CGDirectDisplayID) {
        guard let screen = NSScreen.screens.first(where: { $0.displayID == id }) else { return }
        let area = screen.visibleFrame
        var offsets = savedOffsets
        offsets[String(id)] = [panel.frame.minX - area.minX, area.maxY - panel.frame.maxY]
        UserDefaults.standard.set(offsets, forKey: offsetsKey)
    }
}
