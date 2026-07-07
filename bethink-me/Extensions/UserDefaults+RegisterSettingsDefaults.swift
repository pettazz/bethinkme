import Foundation


extension UserDefaults {
    static func registerSettingsDefaults() {
        standard.register(defaults: [
            SettingsKey.enableAutocorrect.rawValue: kEnableAutocorrectDefault,
            SettingsKey.maxCompletedAgeDays.rawValue: kMaxCompletedAgeDaysDefault,
            SettingsKey.displayNotes.rawValue: kDisplayNotesDefault,
            SettingsKey.displayURLs.rawValue: kDisplayURLsDefault,
            SettingsKey.displayAlarmIcons.rawValue: kDisplayAlarmIconsDefault
        ])
    }
}
