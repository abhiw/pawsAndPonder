import SwiftUI
import UserNotifications

/// Owns the timer, the floating widget and the settings and history windows.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    let timer = PomodoroTimer()
    private var panelController: FloatingPanelController?
    // Open secondary windows by id. They're created on demand and dropped when closed, so their
    // memory isn't held while you're not using them.
    private var openWindows: [String: NSWindow] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Created only once launching has finished, so the widget reliably appears.
        panelController = FloatingPanelController(timer: timer)

        UNUserNotificationCenter.current().delegate = self
        if UserDefaults.standard.bool(forKey: SettingsKey.notificationsEnabled) {
            PhaseAlerts.requestNotificationAuthorization()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer.recordProgress()
    }

    func showSettings() {
        showWindow(id: "settings", title: "Paws and Ponder Settings") {
            SettingsView(timer: timer)
        }
    }

    func showHistory() {
        // Save the running session first, so today's square is up to date.
        timer.recordProgress()
        showWindow(id: "history", title: "Work History") {
            HistoryView(secondsByDay: timer.history.secondsByDay)
        }
    }

    /// Brings a window to the front, creating it if it isn't open.
    private func showWindow(id: String, title: String, content: () -> some View) {
        if openWindows[id] == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.title = title
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setFrameAutosaveName(id)
            openWindows[id] = window
        }
        // A menu-bar-only app isn't active, so bring the window to the front explicitly.
        NSApp.activate()
        openWindows[id]?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = openWindows.first(where: { $0.value === window })?.key else { return }
        openWindows[id] = nil

        // Freed memory otherwise stays reserved for the app until the system runs low. Give it back once
        // the window's views have been torn down.
        Task {
            try? await Task.sleep(for: .seconds(1))
            malloc_zone_pressure_relief(nil, 0)
        }
    }

    // Without this, notifications are suppressed while the app counts as frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}

@main struct MyApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @AppStorage(SettingsKey.keepHistory) private var keepHistory = SettingsDefault.keepHistory

    var body: some Scene {
        let timer = appDelegate.timer

        MenuBarExtra("Paws and Ponder", image: "MenuBarPaw") {
            // Only the phase here: reading the remaining time would rebuild the menu every tick.
            Text(timer.phase.title)

            Divider()

            Button(timer.isRunning ? "Pause" : "Start") {
                timer.toggle()
            }
            Button("Reset") {
                timer.reset()
            }
            Button("Skip to \(timer.phase.next.title)") {
                timer.skip()
            }

            Divider()

            Button("Settings…") {
                appDelegate.showSettings()
            }
            .keyboardShortcut(",")

            if keepHistory {
                Button("History…") {
                    appDelegate.showHistory()
                }
                .keyboardShortcut("y")
            }

            Button("Quit Paws and Ponder") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
