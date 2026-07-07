extension Array where Element == BethinkeryAlarm {
    var sortedAlarms: [BethinkeryAlarm] {
        self.sorted(by: { lalarm, ralarm in
            switch lalarm.kind {
                case .relativeTimeAlarm:
                    if ralarm.kind == .relativeTimeAlarm {
                        return lalarm.offset < ralarm.offset
                    } else {
                        return true
                    }
                case .absoluteTimeAlarm:
                    if ralarm.kind == .absoluteTimeAlarm {
                        guard let lalarmTime = lalarm.time, let ralarmTime = ralarm.time else { return false }
                        return lalarmTime < ralarmTime
                    } else if ralarm.kind == .relativeTimeAlarm {
                        return false
                    } else {
                        return true
                    }
                case .proximityAlarm:
                    if ralarm.kind == .proximityAlarm {
                        return true // who care, maybe alphabetical?
                    } else {
                        return false
                    }
            }
        })
    }
    var earliestAlarm: BethinkeryAlarm? {
        let foundAlarm: BethinkeryAlarm? = self.sortedAlarms.first(where: { alarm in
            alarm.kind == .absoluteTimeAlarm
        })
        return foundAlarm ?? nil
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
            } else if lalarm is ProximityAlarmTemplate {
                if ralarm is ProximityAlarmTemplate {
                    return true // who care
                } else {
                    return false
                }
            } else {
                return true // should never happen
            }
        })
    }
    var earliestAlarm: AbsoluteTimeAlarmTemplate? {
        let foundAlarm: BethinkeryAlarmTemplate? = self.sortedAlarms.first(where: { alarm in
            alarm is AbsoluteTimeAlarmTemplate
        })
        return foundAlarm as? AbsoluteTimeAlarmTemplate ?? nil
    }
}
