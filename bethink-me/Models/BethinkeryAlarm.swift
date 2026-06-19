import EventKit
import SwiftData


@Model
class BethinkeryAlarm: Equatable, Identifiable {
    @Attribute(.unique)
    var id: String
    @Transient var baseAlarm: EKAlarm?

    init(id: String?, baseAlarm: EKAlarm?) {
        self.id = id ?? UUID().uuidString
        self.baseAlarm = baseAlarm
    }

    static func == (lhs: BethinkeryAlarm, rhs: BethinkeryAlarm) -> Bool {
        return lhs.id == rhs.id
    }

    static func == (lhs: BethinkeryAlarm, rhs: EKAlarm) -> Bool {
        if rhs.absoluteDate != nil {
            if let alarm = lhs as? AbsoluteTimeAlarm {
                return alarm.time == rhs.absoluteDate
            }
        } else if rhs.relativeOffset != 0 {
                if let alarm = lhs as? RelativeTimeAlarm {
                    return alarm.offset == rhs.relativeOffset
                }
        } else if rhs.structuredLocation != nil {
            if let alarm = lhs as? ProximityAlarm {
                return alarm.title == rhs.structuredLocation?.title &&
                       alarm.radius == rhs.structuredLocation?.radius &&
                       alarm.location.lat == rhs.structuredLocation?.geoLocation?.coordinate.latitude &&
                       alarm.location.lng == rhs.structuredLocation?.geoLocation?.coordinate.longitude &&
                       alarm.type.rawValue == rhs.proximity.rawValue
            }
        }

        return false
    }
}
