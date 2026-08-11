import Foundation


extension UserDefaults {
    static func registerSettingsDefaults() {
        standard.register(defaults: [
            SettingsKey.enableAutocorrect.rawValue: kEnableAutocorrectDefault,
            SettingsKey.inheritListAlarmsOnImport.rawValue: kInheritListAlarmsOnImportDefault,
            SettingsKey.enableDedupe.rawValue: kEnableDedupeDefault,
            SettingsKey.dedupeCaseSensitive.rawValue: kDedupeCaseSensitiveDefault,
            SettingsKey.dedupeRunOnSync.rawValue: kDedupeRunOnSyncDefault,
            SettingsKey.dedupeNow.rawValue: false,
            SettingsKey.maxCompletedAgeDays.rawValue: kMaxCompletedAgeDaysDefault,
            SettingsKey.displayNotes.rawValue: kDisplayNotesDefault,
            SettingsKey.displayURLs.rawValue: kDisplayURLsDefault,
            SettingsKey.displayAlarmIcons.rawValue: kDisplayAlarmIconsDefault
        ])
    }
}
