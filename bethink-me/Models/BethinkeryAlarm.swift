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

    var location: LatLng {
        get {
            LatLng(lat: locationLat, lng: locationLng)
        }
        set {
            locationLat = newValue.lat
            locationLng = newValue.lng
        }
    }

    var representsDueDate: Bool {
        id.hasPrefix("synth-")
    }


    init(id: String? = nil, kind: BethinkeryAlarmKind) {
        self.id = id ?? UUID().uuidString
        self.kind = kind
    }

    static func absoluteTime(id: String? = nil,
                             time: Date,
                             isAllDay: Bool) -> BethinkeryAlarm {
        let alarm = BethinkeryAlarm(id: id, kind: .absoluteTimeAlarm)
        alarm.time = time
        alarm.isAllDay = isAllDay

        return alarm
    }

    static func relativeTime(id: String? = nil,
                             offset: TimeInterval) -> BethinkeryAlarm {
        let alarm = BethinkeryAlarm(id: id, kind: .relativeTimeAlarm)
        alarm.offset = offset

        return alarm
    }

    static func proximity(id: String? = nil,
                          title: String,
                          radius: Double,
                          location: LatLng,
                          proximityType: AlarmProximityType) -> BethinkeryAlarm {
        let alarm = BethinkeryAlarm(id: id, kind: .proximityAlarm)
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
                guard let rhsLocation = rhs.structuredLocation else { return false }
                guard let rhsGeo = rhsLocation.geoLocation else { return false }
                let lhsLoc = CLLocation(latitude: lhs.location.lat, longitude: lhs.location.lng),
                    rhsLoc = CLLocation(latitude: rhsGeo.coordinate.latitude, longitude: rhsGeo.coordinate.longitude),
                    distance = lhsLoc.distance(from: rhsLoc)
                return lhs.title == normalizeProxTitle(rhsLocation.title) &&
                       abs(lhs.radius - rhsLocation.radius) <= kProximityAlarmRadiusEqualityToleranceMeters &&
                       distance <= kProximityAlarmCoordinateEqualityToleranceMeters &&
                       lhs.proximityType.rawValue == rhs.proximity.rawValue
        }
    }

    private static func normalizeProxTitle(_ title: String?) -> String {
        let extant = title ?? ""
        return extant.isEmpty ? "Location" : extant
    }

    static func fromEKAlarm(_ alarm: EKAlarm) throws -> BethinkeryAlarm? {
        if let absoluteDate = alarm.absoluteDate {
            guard alarm.relativeOffset == 0 else {
                throw BethinkMeError("tried to make a BethinkeryTimeAlarm from an EKAlarm with an offset")
            }

            return .absoluteTime(time: absoluteDate,
                                 isAllDay: false)
        } else if alarm.relativeOffset != 0 {
            return .relativeTime(offset: alarm.relativeOffset)
        } else if let loc = alarm.structuredLocation, let geoLoc = loc.geoLocation {
            let proxType: AlarmProximityType = switch alarm.proximity {
                case .enter: .enter
                case .leave: .leave
                default: .nothing
            }

            return .proximity(title: normalizeProxTitle(loc.title),
                              radius: loc.radius,
                              location: LatLng(lat: geoLoc.coordinate.latitude,
                                               lng: geoLoc.coordinate.longitude),
                              proximityType: proxType)
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

    func isDuplicate(of alarm: BethinkeryAlarm) -> Bool {
        if title == alarm.title && kind == alarm.kind {
            switch kind {
                case .absoluteTimeAlarm:
                    guard let ltime = time, let rtime = alarm.time else { return false }
                    return isAllDay == alarm.isAllDay &&
                           abs(ltime.timeIntervalSince(rtime)) < kAbsoluteAlarmEqualityToleranceSeconds
                case .relativeTimeAlarm:
                    return offset == alarm.offset
                case .proximityAlarm:
                    return title == alarm.title &&
                           radius == alarm.radius &&
                           location.lat == alarm.location.lat &&
                           location.lng == alarm.location.lng &&
                           proximityType.rawValue == alarm.proximityType.rawValue
            }
        } else {
            return false
        }
    }
}
