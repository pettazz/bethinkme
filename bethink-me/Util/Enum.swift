import Foundation


// because you basically can't put any non-model complex types into SwiftData
enum AlarmProximityType: Int, Codable, CaseIterable {
    case nothing = 0
    case enter = 1
    case leave = 2

    var title: String {
        switch self {
            case .nothing:
                return "None"
            case .enter:
                return "Arriving at"
            case .leave:
                return "Leaving"
        }
    }
}

enum AvailableAlarmTypes: String, CaseIterable {
    case absoluteTimeAlarm = "Exact Time"
    case relativeTimeAlarm = "Relative Time"
    case proximityAlarm = "Location"
}

enum Env: String {
    case debug
    case testFlight
    case appStore
}

enum SettingsKey: String {
    case enableAutocorrect = "settings.enableAutocorrect"
    case maxCompletedAgeDays = "settings.maxCompletedAgeDays"
    case displayNotes = "settings.displayNotes"
    case displayURLs = "settings.displayURLs"
}

enum TimeAlarmIntervalDirection: Int, CaseIterable {
    case before = -1
    case after = 1
}

enum TimeAlarmIntervalUnits: TimeInterval, CaseIterable {
    case minutes = 60
    case hours = 3_600
    case days = 86_400
    case weeks = 604_800
    case months = 2_592_000  // well...
}
