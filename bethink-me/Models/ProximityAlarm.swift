import EventKit
import SwiftData


nonisolated struct LatLng: Codable, Hashable {
    var lat: Double
    var lng: Double
}

@available(iOS 26.0, *)
@Model
final class ProximityAlarm: BethinkeryAlarm {
    var title: String
    var radius: Double
    var location: LatLng
    var type: AlarmProximityType

    init(id: String? = nil,
         title: String,
         radius: Double,
         location: LatLng,
         type: AlarmProximityType,
         baseAlarm: EKAlarm? = nil) {
        self.title = title
        self.radius = radius
        self.location = location
        self.type = type

        super.init(id: id, baseAlarm: baseAlarm)
    }

    static func fromEKAlarm(_ alarm: EKAlarm) throws -> ProximityAlarm {
        guard alarm.structuredLocation?.geoLocation != nil  else {
            throw BethinkMeError("tried to make a BethinkeryProximityAlarm from an EKAlarm with no location info")
        }

        let loc = alarm.structuredLocation!
        let proxType: AlarmProximityType = switch alarm.proximity {
            case .enter: .enter
            case .leave: .leave
            default: .nothing
        }

        return ProximityAlarm(
            id: nil,
            title: loc.title ?? "Location",
            radius: loc.radius,
            location: LatLng(
                lat: loc.geoLocation!.coordinate.latitude,
                lng: loc.geoLocation!.coordinate.longitude),
            type: proxType,
            baseAlarm: alarm
        )
    }
}
