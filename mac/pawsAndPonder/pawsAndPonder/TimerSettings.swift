import Foundation

/// How the widget shows the time left.
enum TimerDisplayStyle: String, CaseIterable, Identifiable {
    case digital
    case bar

    var id: Self { self }

    var title: String {
        switch self {
        case .digital: "Digital timer"
        case .bar: "Progress bar"
        }
    }
}

/// Light or dark look for the widget, or following the system setting.
enum WidgetTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// UserDefaults keys shared by the settings window (via @AppStorage) and the timer.
enum SettingsKey {
    static let workMinutes = "workMinutes"
    static let breakMinutes = "breakMinutes"
    static let autoStartBreak = "autoStartBreak"
    static let autoStartWork = "autoStartWork"
    static let soundEnabled = "soundEnabled"
    static let notificationsEnabled = "notificationsEnabled"
    static let showOnAllDisplays = "showOnAllDisplays"
    static let displayStyle = "displayStyle"
    static let widgetTheme = "widgetTheme"
    static let keepHistory = "keepHistory"
    /// Width of the time area (bar plus its label) in bar mode.
    static let barWidth = "barWidth"

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            workMinutes: SettingsDefault.workMinutes,
            breakMinutes: SettingsDefault.breakMinutes,
            autoStartBreak: SettingsDefault.autoStartBreak,
            autoStartWork: SettingsDefault.autoStartWork,
            soundEnabled: SettingsDefault.soundEnabled,
            notificationsEnabled: SettingsDefault.notificationsEnabled,
            showOnAllDisplays: SettingsDefault.showOnAllDisplays,
            displayStyle: SettingsDefault.displayStyle.rawValue,
            widgetTheme: SettingsDefault.widgetTheme.rawValue,
            keepHistory: SettingsDefault.keepHistory,
            barWidth: SettingsDefault.barWidth
        ])
    }
}

/// Default values, used for registration and as the @AppStorage fallbacks so they can't drift apart.
enum SettingsDefault {
    static let workMinutes = 25
    static let breakMinutes = 5
    static let autoStartBreak = true
    static let autoStartWork = false
    static let soundEnabled = true
    static let notificationsEnabled = true
    static let showOnAllDisplays = false
    static let displayStyle = TimerDisplayStyle.digital
    static let widgetTheme = WidgetTheme.system
    static let keepHistory = false
    static let barWidth = 104.0
}
