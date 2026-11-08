import AppKit
import UserNotifications

/// Sound and notification shown when a phase ends, each controlled by its own setting.
enum PhaseAlerts {
    /// Asks for permission to post notifications. Safe to call repeatedly; the system only prompts once.
    static func requestNotificationAuthorization() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
        }
    }

    /// `nextMinutes` is the length of the phase that follows the one that just finished.
    static func phaseDidFinish(_ finished: PomodoroTimer.Phase, nextMinutes: Int) {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: SettingsKey.soundEnabled) {
            NSSound(named: "Glass")?.play()
        }

        if defaults.bool(forKey: SettingsKey.notificationsEnabled) {
            let content = UNMutableNotificationContent()
            switch finished {
            case .work:
                content.title = "Work session finished"
                content.body = "Time for a \(nextMinutes) minute break."
            case .rest:
                content.title = "Break is over"
                content.body = "Ready for a \(nextMinutes) minute work session."
            }
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            Task {
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }
}
