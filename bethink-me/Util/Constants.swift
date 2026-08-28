import Foundation

// settings defaults
let kEnableAutocorrectDefault: Bool = true
let kEnableFullRangePriorityDefault: Bool = false
let kInheritListAlarmsOnImportDefault: InheritListAlarmsOnImportOptions = .whenEmpty
let kEnableDedupeDefault: Bool = true
let kDedupeCaseSensitiveDefault: Bool = true
let kDedupeRunOnSyncDefault: Bool = true
let kMaxCompletedAgeDaysDefault: Int = 30
let kDisplayNotesDefault: Bool = true
let kDisplayPriorityDefault: Bool = true
let kDisplayAlarmIconsDefault: Bool = true

// sync coordinator timings
let kChangeGracePeriodSeconds: TimeInterval = 3.0
let kForegroundedSyncGracePeriodSeconds: TimeInterval = 60.0
let kSyncRequestDebounceMilliseconds: TimeInterval = 300

// absolute alarm comparison tolerance for drift
let kAbsoluteAlarmEqualityToleranceSeconds: TimeInterval = 1

// proximity alarm comparison tolerance for drift
let kProximityAlarmCoordinateEqualityToleranceMeters: Double = 10 // swiftlint:disable:this identifier_name
let kProximityAlarmRadiusEqualityToleranceMeters: Double = 1 // swiftlint:disable:this identifier_name
