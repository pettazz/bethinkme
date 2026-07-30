import Foundation

// settings defaults
let kEnableAutocorrectDefault: Bool = true
let kEnableDedupeDefault: Bool = true
let kDedupeCaseSensitiveDefault: Bool = true
let kDedupeRunOnSyncDefault: Bool = true
let kMaxCompletedAgeDaysDefault: Int = 30
let kDisplayNotesDefault: Bool = true
let kDisplayURLsDefault: Bool = false
let kDisplayAlarmIconsDefault: Bool = true

// sync coordinator timings
let kChangeGracePeriodSeconds: TimeInterval = 3.0
let kForegroundedSyncGracePeriodSeconds: TimeInterval = 60.0
let kSyncRequestDebounceMilliseconds: TimeInterval = 300

// absolute alarm comparison tolerance for drift
let kAbsoluteAlarmEqualityToleranceSeconds: TimeInterval = 1
