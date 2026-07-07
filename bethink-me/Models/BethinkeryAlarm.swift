import EventKit
import SwiftData


struct LatLng: Codable, Hashable {
    var lat: Double
    var lng: Double
}

@Model
final class BethinkeryAlarm: Equatable, Identifiable {
    @Attribute(.unique)
    var id: String = UUID().uuidString
    var kind: BethinkeryAlarmKind

    var time: Date?
    var isAllDay: Bool = false

    var offset: TimeInterval = 0

    var title: String = ""
    var radius: Double = 0
    var locationLat: Double = 0
    var locationLng: Double = 0
    var proximityType: AlarmProximityType = AlarmProximityType.nothing

    @Transient var baseAlarm: EKAlarm?

    var location: LatLng {
        get {
            LatLng(lat: locationLat, lng: locationLng)
        }
        set {
            locationLat = newValue.lat
            locationLng = newValue.lng
        }
    }


    init(id: String? = nil, kind: BethinkeryAlarmKind, baseAlarm: EKAlarm?) {
        self.id = id ?? UUID().uuidString
        self.kind = kind
        self.baseAlarm = baseAlarm
    }

    static func absoluteTime(id: String? = nil,
                             time: Date,
                             isAllDay: Bool,
                             baseAlarm: EKAlarm? = nil) -> BethinkeryAlarm {
        let alarm = BethinkeryAlarm(id: id, kind: .absoluteTimeAlarm, baseAlarm: baseAlarm)
        alarm.time = time
        alarm.isAllDay = isAllDay

        return alarm
    }

    static func relativeTime(id: String? = nil,
                             offset: TimeInterval,
                             baseAlarm: EKAlarm? = nil) -> BethinkeryAlarm {
        let alarm = BethinkeryAlarm(id: id, kind: .relativeTimeAlarm, baseAlarm: baseAlarm)
        alarm.offset = offset

        return alarm
    }

    static func proximity(id: String? = nil,
                          title: String,
                          radius: Double,
                          location: LatLng,
                          proximityType: AlarmProximityType,
                          baseAlarm: EKAlarm? = nil) -> BethinkeryAlarm {
        let alarm = BethinkeryAlarm(id: id, kind: .proximityAlarm, baseAlarm: baseAlarm)
        alarm.title = title
        alarm.radius = radius
        alarm.location = location
        alarm.proximityType = proximityType

        return alarm
    }


    static func == (lhs: BethinkeryAlarm, rhs: BethinkeryAlarm) -> Bool {
        return lhs.id == rhs.id
    }

    static func == (lhs: BethinkeryAlarm, rhs: EKAlarm) -> Bool {
        switch lhs.kind {
            case .absoluteTimeAlarm:
                guard let ltime = lhs.time, let rabsoluteDate = rhs.absoluteDate else { return false }
                return abs(ltime.timeIntervalSince(rabsoluteDate)) < kAbsoluteAlarmEqualityToleranceSeconds
            case .relativeTimeAlarm:
                return rhs.relativeOffset != 0 && lhs.offset == rhs.relativeOffset
            case .proximityAlarm:
                guard let loc = rhs.structuredLocation else { return false }
                return lhs.title == loc.title &&
                       lhs.radius == loc.radius &&
                       lhs.location.lat == loc.geoLocation?.coordinate.latitude &&
                       lhs.location.lng == loc.geoLocation?.coordinate.longitude &&
                       lhs.proximityType.rawValue == rhs.proximity.rawValue
        }
    }


    static func fromEKAlarm(_ alarm: EKAlarm) throws -> BethinkeryAlarm? {
        if let absoluteDate = alarm.absoluteDate {
            guard alarm.relativeOffset == 0 else {
                throw BethinkMeError("tried to make a BethinkeryTimeAlarm from an EKAlarm with an offset")
            }

            return .absoluteTime(time: absoluteDate,
                                 isAllDay: false,
                                 baseAlarm: alarm)
        } else if alarm.relativeOffset != 0 {
            return .relativeTime(offset: alarm.relativeOffset,
                                 baseAlarm: alarm)
        } else if let loc = alarm.structuredLocation, let geoLoc = loc.geoLocation {
            let proxType: AlarmProximityType = switch alarm.proximity {
                case .enter: .enter
                case .leave: .leave
                default: .nothing
            }

            return .proximity(title: loc.title ?? "Location",
                              radius: loc.radius,
                              location: LatLng(lat: geoLoc.coordinate.latitude,
                                               lng: geoLoc.coordinate.longitude),
                              proximityType: proxType,
                              baseAlarm: alarm)
        }

        return nil
    }

    func toTemplate(newInstance: Bool = false) -> (any BethinkeryAlarmTemplate)? {
        switch self.kind {
            case .absoluteTimeAlarm:
                guard let time else { return nil }
                return AbsoluteTimeAlarmTemplate(id: newInstance ? nil : id,
                                                 time: time,
                                                 isAllDay: isAllDay)
            case .relativeTimeAlarm:
                return RelativeTimeAlarmTemplate(id: newInstance ? nil : id,
                                                 offset: offset)
            case .proximityAlarm:
                return ProximityAlarmTemplate(id: newInstance ? nil : id,
                                              title: title,
                                              radius: radius,
                                              locationLat: locationLat,
                                              locationLng: locationLng,
                                              proximityType: proximityType)
        }
    }

}
