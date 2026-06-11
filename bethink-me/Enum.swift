enum SettingsKey: String {
    case enableAutocorrect = "settings.enableAutocorrect"
    case maxCompletedAgeDays = "settings.maxCompletedAgeDays"
    case displayNotes = "settings.displayNotes"
    case displayURLs = "settings.displayURLs"
}

enum AvailableAlarmTypes {
    case timeAlarm
    case locationAlarm
}

// because you basically can't put any non-model complex types into SwifData 
enum AlarmProximityType: Int, Codable {
    case nothing = 0
    case enter = 1
    case leave = 2
}
