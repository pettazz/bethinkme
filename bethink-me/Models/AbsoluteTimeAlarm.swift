import EventKit
import SwiftData


@available(iOS 26.0, *)
@Model
final class AbsoluteTimeAlarm: BethinkeryAlarm {
    var time: Date
    var isAllDay: Bool = false

    init(id: String? = nil, time: Date, isAllDay: Bool, baseAlarm: EKAlarm? = nil) {
        self.time = time
        self.isAllDay = isAllDay

        super.init(id: id, baseAlarm: baseAlarm)
    }

    static func fromEKAlarm(_ alarm: EKAlarm) throws -> AbsoluteTimeAlarm {
        guard alarm.absoluteDate != nil  else {
            throw BethinkMeError("tried to make a BethinkeryTimeAlarm from an EKAlarm with no time info")
        }
        guard alarm.relativeOffset == 0 else {
            throw BethinkMeError("tried to make a BethinkeryTimeAlarm from an EKAlarm with an offset")
        }

        return AbsoluteTimeAlarm(
            id: nil,
            time: alarm.absoluteDate!,
            isAllDay: false,
            baseAlarm: alarm
        )
    }
}
