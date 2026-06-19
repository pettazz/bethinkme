import EventKit
import SwiftData


@available(iOS 26.0, *)
@Model
final class RelativeTimeAlarm: BethinkeryAlarm {
    var offset: TimeInterval

    init(id: String? = nil, offset: TimeInterval, baseAlarm: EKAlarm? = nil) {
        self.offset = offset

        super.init(id: id, baseAlarm: baseAlarm)
    }

    static func fromEKAlarm(_ alarm: EKAlarm) throws -> RelativeTimeAlarm {
        guard alarm.absoluteDate == nil  else {
            throw BethinkMeError("tried to make a BethinkeryRelativeTimeAlarm from an EKAlarm with an absolute time")
        }

        return RelativeTimeAlarm(
            id: nil,
            offset: alarm.relativeOffset,
            baseAlarm: alarm
        )
    }
}
