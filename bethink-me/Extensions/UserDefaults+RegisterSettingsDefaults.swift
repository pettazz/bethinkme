import Foundation


extension UserDefaults {
    static func registerSettingsDefaults() {
        standard.register(defaults: [
            SettingsKey.enableAutocorrect.rawValue: kEnableAutocorrectDefault,
            SettingsKey.enableAutoCleanup.rawValue: kEnableAutoCleanupDefault,
            SettingsKey.autoCleanupThresholdDays.rawValue: kAutoCleanupThresholdDaysDefault,
            SettingsKey.enableFullRangePriority.rawValue: kEnableFullRangePriorityDefault,
            SettingsKey.inheritListAlarmsOnImport.rawValue: kInheritListAlarmsOnImportDefault.rawValue,
            SettingsKey.enableDedupe.rawValue: kEnableDedupeDefault,
            SettingsKey.dedupeCaseSensitive.rawValue: kDedupeCaseSensitiveDefault,
            SettingsKey.dedupeRunOnSync.rawValue: kDedupeRunOnSyncDefault,
            SettingsKey.dedupeNow.rawValue: false,
            SettingsKey.maxCompletedAgeDays.rawValue: kMaxCompletedAgeDaysDefault,
            SettingsKey.displayNotes.rawValue: kDisplayNotesDefault,
            SettingsKey.displayPriority.rawValue: kDisplayPriorityDefault,
            SettingsKey.displayDueDate.rawValue: kDisplayDueDateDefault,
            SettingsKey.displayAlarmIcons.rawValue: kDisplayAlarmIconsDefault,
            SettingsKey.sortType.rawValue: kSortTypeDefault.rawValue
        ])
    }
}
