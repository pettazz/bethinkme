extension Array where Element == BethinkeryAlarm {
    var sortedAlarms: [BethinkeryAlarm] {
        self.sorted(by: { lalarm, ralarm in
            if let ltimeAlarm = lalarm as? RelativeTimeAlarm {
                if let rtimeAlarm = ralarm as? RelativeTimeAlarm {
                    return ltimeAlarm.offset < rtimeAlarm.offset
                } else {
                    return true
                }
            } else if let ltimeAlarm = lalarm as? AbsoluteTimeAlarm {
                if let rtimeAlarm = ralarm as? AbsoluteTimeAlarm {
                    return ltimeAlarm.time < rtimeAlarm.time
                } else if ralarm is RelativeTimeAlarm {
                    return false
                } else {
                    return true
                }
            } else if lalarm is ProximityAlarm {
                if ralarm is ProximityAlarm {
                    return true // who care
                } else {
                    return false
                }
            } else {
                return true // should never happen
            }
        })
    }
    var earliestAlarm: AbsoluteTimeAlarm? {
        let foundAlarm: BethinkeryAlarm? = self.sortedAlarms.first(where: { alarm in
            alarm is AbsoluteTimeAlarm
        })
        return foundAlarm as? AbsoluteTimeAlarm ?? nil
    }
}
