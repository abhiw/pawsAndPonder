import SwiftUI

struct SettingsView: View {
    let timer: PomodoroTimer

    @AppStorage(SettingsKey.workMinutes) private var workMinutes = SettingsDefault.workMinutes
    @AppStorage(SettingsKey.breakMinutes) private var breakMinutes = SettingsDefault.breakMinutes
    @AppStorage(SettingsKey.autoStartBreak) private var autoStartBreak = SettingsDefault.autoStartBreak
    @AppStorage(SettingsKey.autoStartWork) private var autoStartWork = SettingsDefault.autoStartWork
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = SettingsDefault.soundEnabled
    @AppStorage(SettingsKey.notificationsEnabled) private var notificationsEnabled = SettingsDefault.notificationsEnabled
    @AppStorage(SettingsKey.showOnAllDisplays) private var showOnAllDisplays = SettingsDefault.showOnAllDisplays
    @AppStorage(SettingsKey.displayStyle) private var displayStyle = SettingsDefault.displayStyle
    @AppStorage(SettingsKey.widgetTheme) private var widgetTheme = SettingsDefault.widgetTheme
    @AppStorage(SettingsKey.keepHistory) private var keepHistory = SettingsDefault.keepHistory

    var body: some View {
        Form {
            Section("Durations") {
                MinutesField(title: "Work", value: $workMinutes, range: 1...180)
                MinutesField(title: "Break", value: $breakMinutes, range: 1...60)
            }

            Section("Next phase") {
                Toggle("Start break automatically after work", isOn: $autoStartBreak)
                Toggle("Start work automatically after break", isOn: $autoStartWork)
            }

            Section("When a phase ends") {
                Toggle("Play a sound", isOn: $soundEnabled)
                Toggle("Show a notification", isOn: $notificationsEnabled)
            }

            Section("Widget") {
                Picker("Show time as", selection: $displayStyle) {
                    ForEach(TimerDisplayStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                Picker("Theme", selection: $widgetTheme) {
                    ForEach(WidgetTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                Toggle("Show on all displays", isOn: $showOnAllDisplays)
            }

            Section {
                Toggle("Keep work history", isOn: $keepHistory)
            } header: {
                Text("History")
            } footer: {
                Text("Saves how long you work each day, for the last \(WorkHistory.monthsKept) months.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: workMinutes) { timer.applySettings() }
        .onChange(of: breakMinutes) { timer.applySettings() }
        .onChange(of: notificationsEnabled) {
            if notificationsEnabled { PhaseAlerts.requestNotificationAuthorization() }
        }
    }
}
