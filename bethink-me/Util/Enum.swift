import Foundation
import SwiftUI


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

enum BethinkeryAlarmKind: Int, Codable, CaseIterable {
    case absoluteTimeAlarm = 1
    case relativeTimeAlarm = 2
    case proximityAlarm = 3

    var title: String {
        switch self {
            case .absoluteTimeAlarm:
                return "Exact Time"
            case .relativeTimeAlarm:
                return "Relative Time"
            case .proximityAlarm:
                return "Location"
        }
    }
}

enum BethinkeryPriority: Int, Codable, CaseIterable {
    case unset = 0
    case highest = 1
    case two = 2
    case three = 3
    case four = 4
    case medium = 5
    case six = 6
    case seven = 7
    case eight = 8
    case lowest = 9

    static let shortRangeCases: [BethinkeryPriority] = [.highest, .medium, .lowest]

    var shortened: Int {
        switch self.rawValue {
            case 1...3:
                return 1
            case 4...6:
                return 5
            case 7...9:
                return 9
            default:
                return 0
        }
    }

    var shortRangeTitle: String {
        switch self.shortened {
            case 0:
                return "None"
            case 1:
                return "High"
            case 5:
                return "Medium"
            case 9:
                return "Low"
            default:
                return "Invalid"
        }
    }

    var shortRangeIcon: String? {
        switch self.shortened {
            case 0:
                return nil
            case 1:
                return "exclamationmark.3"
            case 5:
                return "exclamationmark.2"
            case 9:
                return "exclamationmark"
            default:
                return "exclamationmark.questionmark"
        }
    }

    var title: String {
        switch self {
            case .unset:
                return "None"
            case .highest:
                return "Highest"
            case.two:
                return "High"
            case .three:
                return "Medium-High"
            case .four:
                return "Higher"
            case .medium:
                return "Medium"
            case .six:
                return "Lower"
            case .seven:
                return "Medium-Low"
            case .eight:
                return "Low"
            case .lowest:
                return "Lowest"
        }
    }

    var icon: String? {
        switch self {
            case .unset:
                return nil
            case .highest:
                return "1.lane"
            case.two:
                return "2.lane"
            case .three:
                return "3.lane"
            case .four:
                return "4.lane"
            case .medium:
                return "5.lane"
            case .six:
                return "6.lane"
            case .seven:
                return "7.lane"
            case .eight:
                return "8.lane"
            case .lowest:
                return "9.lane"
        }
    }
}

enum BethinkerySorting: String {
    case custom
    case titleAsc
    case titleDesc
    case dueDateAsc
    case dueDateDesc
    case priorityAsc
    case priorityDesc

    var title: String {
        switch self {
            case .custom:
                return "Custom"
            case .titleAsc, .titleDesc:
                return "Alphabetical"
            case .dueDateAsc, .dueDateDesc:
                return "Due Date"
            case .priorityAsc, .priorityDesc:
                return "Priority"
        }
    }

    var description: String {
        switch self {
            case .custom:
                return "Custom"
            case .titleAsc:
                return "A to Z"
            case .titleDesc:
                return "Z to A"
            case .dueDateAsc:
                return "Soonest to Latest"
            case .dueDateDesc:
                return "Latest to Soonest"
            case .priorityAsc:
                return "Highest to Lowest"
            case .priorityDesc:
                return "Lowest to Highest"
        }
    }

    var icon: String {
        switch self {
            case .custom:
                return "arrow.up.arrow.down" // nobody ever uses this anyway
            case .titleAsc, .dueDateAsc, .priorityAsc:
                return "arrow.down.to.line.compact"
            case .titleDesc, .dueDateDesc, .priorityDesc:
                return "arrow.up.to.line.compact"
        }
    }
}

enum Env: String {
    case debug
    case testFlight
    case appStore
}

enum SettingsKey: String {
    case enableAutocorrect = "settings.enableAutocorrect"
    case enableAutoCleanup = "settings.enableAutoCleanup"
    case autoCleanupThresholdDays = "settings.autoCleanupThresholdDays"
    case enableFullRangePriority = "settings.enableFullRangePriority"
    case inheritListAlarmsOnImport = "settings.inheritListAlarmsOnImport"
    case enableDedupe = "settings.enableDedupe"
    case dedupeCaseSensitive = "settings.dedupeCaseSensitive"
    case dedupeRunOnSync = "settings.dedupeRunOnSync"
    case dedupeNow = "settings.dedupeNow"
    case maxCompletedAgeDays = "settings.maxCompletedAgeDays"
    case displayNotes = "settings.displayNotes"
    case displayPriority = "settings.displayPriority"
    case displayDueDate = "settings.displayDueDate"
    case displayAlarmIcons = "settings.displayAlarmIcons"

    case sortType = "settings.sortType"
}

enum InheritListAlarmsOnImportOptions: String, CaseIterable {
    case always
    case whenEmpty
    case never

    var title: String {
        switch self {
            case .always:
                return "Always"
            case .whenEmpty:
                return "When empty"
            case .never:
                return "Never"
        }
    }
}

enum SyncStatus {
    case ok
    case unavailable
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
