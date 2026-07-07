import Foundation


protocol BethinkeryAlarmTemplate {
    var id: String { get }
    func toModel() -> BethinkeryAlarm
}

struct AbsoluteTimeAlarmTemplate: BethinkeryAlarmTemplate {
    var id: String
    var time: Date
    var isAllDay: Bool

    init(id: String?, time: Date, isAllDay: Bool) {
        self.id = id ?? UUID().uuidString
        self.time = time
        self.isAllDay = isAllDay
    }

    func toModel() -> BethinkeryAlarm {
        .absoluteTime(id: id, time: time, isAllDay: isAllDay)
    }
}

struct RelativeTimeAlarmTemplate: BethinkeryAlarmTemplate {
    var id: String
    var offset: TimeInterval

    init(id: String?, offset: TimeInterval) {
        self.id = id ?? UUID().uuidString
        self.offset = offset
    }

    func toModel() -> BethinkeryAlarm {
        .relativeTime(id: id, offset: offset)
    }
}

struct ProximityAlarmTemplate: BethinkeryAlarmTemplate {
    var id: String
    var title: String
    var radius: Double
    var locationLat: Double
    var locationLng: Double
    var proximityType: AlarmProximityType

    init(id: String?,
         title: String,
         radius: Double,
         locationLat: Double,
         locationLng: Double,
         proximityType: AlarmProximityType) {
        self.id = id ?? UUID().uuidString
        self.title = title
        self.radius = radius
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.proximityType = proximityType
    }

    func toModel() -> BethinkeryAlarm {
        .proximity(id: id,
                   title: title,
                   radius: radius,
                   location: LatLng(lat: locationLat, lng: locationLng),
                   proximityType: proximityType)
    }
}
