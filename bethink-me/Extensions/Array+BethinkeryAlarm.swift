import Foundation


extension Array where Element == BethinkeryAlarm {
    // TODO: remove if not used
//    var sortedAlarms: [BethinkeryAlarm] {
//        self.sorted(by: { lalarm, ralarm in
//            switch lalarm.kind {
//                case .relativeTimeAlarm:
//                    if ralarm.kind == .relativeTimeAlarm {
//                        return lalarm.offset < ralarm.offset
//                    } else {
//                        return true
//                    }
//                case .absoluteTimeAlarm:
//                    if ralarm.kind == .absoluteTimeAlarm {
//                        guard let lalarmTime = lalarm.time, let ralarmTime = ralarm.time else { return false }
//                        return lalarmTime < ralarmTime
//                    } else if ralarm.kind == .relativeTimeAlarm {
//                        return false
//                    } else {
//                        return true
//                    }
//                case .proximityAlarm:
//                    if ralarm.kind == .proximityAlarm {
//                        return ralarm.title < lalarm.title
//                    } else {
//                        return false
//                    }
//            }
//        })
//    }
    var earliestAlarm: BethinkeryAlarm? {
        filter({ $0.kind == .absoluteTimeAlarm })
            .min(by: { ($0.time ?? .distantFuture) < ($1.time ?? .distantFuture) })
    }
}

// entirely a duplicate of the above for templates
// too lazy to genericize it 
extension Array where Element == any BethinkeryAlarmTemplate {
    var sortedAlarms: [any BethinkeryAlarmTemplate] {
        self.sorted(by: { lalarm, ralarm in
            if let ltimeAlarm = lalarm as? RelativeTimeAlarmTemplate {
                if let rtimeAlarm = ralarm as? RelativeTimeAlarmTemplate {
                    return ltimeAlarm.offset < rtimeAlarm.offset
                } else {
                    return true
                }
            } else if let ltimeAlarm = lalarm as? AbsoluteTimeAlarmTemplate {
                if let rtimeAlarm = ralarm as? AbsoluteTimeAlarmTemplate {
                    return ltimeAlarm.time < rtimeAlarm.time
                } else if ralarm is RelativeTimeAlarmTemplate {
                    return false
                } else {
                    return true
                }
            } else if let lprox = lalarm as? ProximityAlarmTemplate {
                if let rprox = ralarm as? ProximityAlarmTemplate {
                    return lprox.title < rprox.title
                } else {
                    return false
                }
            } else {
                return true // should never happen
            }
        })
    }
    var earliestAlarm: AbsoluteTimeAlarmTemplate? {
        compactMap({ $0 as? AbsoluteTimeAlarmTemplate }).min(by: { $0.time < $1.time })
    }
}
