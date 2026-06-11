import EventKit
import SwiftData
import SwiftUI


@Model
final class BethinkeryList: Equatable, Identifiable {
    @Attribute(.unique)
    var id: String
    @Relationship(deleteRule: .cascade, inverse: \Bethinkery.list)
    var bethinkeries: [Bethinkery] = []
    var ordinal: Int = -1
    var title: String
    var hexColor: String
    @Transient private var calendar: EKCalendar?

    var hasCalendar: Bool { return self.calendar != nil }


    init(id: String, title: String, hexColor: String, calendar: EKCalendar) {
        self.id = id
        self.title = title
        self.hexColor = hexColor
        self.calendar = calendar
    }

    convenience init(calendar: EKCalendar) {
        self.init(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            hexColor: Color(cgColor: calendar.cgColor).toHex(),
            calendar: calendar)
    }


    static func == (lhs: BethinkeryList, rhs: BethinkeryList) -> Bool {
        return lhs.id == rhs.id
    }

    func load(from calendar: EKCalendar) {
        self.id = calendar.calendarIdentifier
        self.title = calendar.title
        self.hexColor = Color(cgColor: calendar.cgColor).toHex()
        self.calendar = calendar
    }

    func toCalendar() throws -> EKCalendar {
        guard self.hasCalendar else { throw BethinkMeError("tried to access EKCalendar before it was set") }
        self.calendar!.title = self.title
        // yes we are constantly going back and forth between Color and cgColor and String,
        // but SwiftData doesn't want to save Color/UIColor so okay whatever man 
        self.calendar!.cgColor = Color(hex: self.hexColor).cgColor

        return self.calendar!
    }
}

@Model
final class Bethinkery: Equatable, Identifiable {
    @Attribute(.unique)
    var id: String
    var list: BethinkeryList
    var ordinal: Int = -1
    var title: String
    var isCompleted: Bool
    var freshlyCompleted: Bool = false
    var notes: String?
    var url: URL?
    var dueDate: Date?
    @Relationship(deleteRule: .cascade)
    var alarms: [BethinkeryAlarm] = []
    @Transient var reminder: EKReminder?

    var hasNotes: Bool { return self.notes != nil && !self.notes!.isEmpty }
    var hasUrl: Bool { return self.url != nil }
    var hasReminder: Bool { return self.reminder != nil }
    var hasAlarms: Bool { return !self.alarms.isEmpty }


    init(id: String,
         list: BethinkeryList,
         title: String,
         isCompleted: Bool,
         notes: String?,
         url: URL?,
         dueDate: Date?,
         reminder: EKReminder) {
        self.id = id
        self.list = list
        self.title = title
        self.isCompleted = isCompleted
        self.notes = notes
        self.url = url
        self.dueDate = dueDate
        self.reminder = reminder
    }

    // used when creating a new Bethinkery from an existing EKReminder
    convenience init(reminder: EKReminder, list: BethinkeryList) throws {
        self.init(
            id: reminder.calendarItemIdentifier,
            list: list,
            title: reminder.title,
            isCompleted: reminder.isCompleted,
            notes: reminder.notes,
            url: reminder.url,
            dueDate: reminder.dueDateComponents?.date,
            reminder: reminder)

        try addAlarms(from: reminder)
    }


    static func == (lhs: Bethinkery, rhs: Bethinkery) -> Bool {
        return lhs.id == rhs.id && lhs.list == rhs.list
    }

    // used when updating a stored Bethinkery with an existing EKReminder
    // (capture changes made outside the app)
    func load(from reminder: EKReminder) throws {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title
        self.isCompleted = reminder.isCompleted
        self.freshlyCompleted = false
        self.notes = reminder.notes
        self.url = reminder.url
        self.dueDate = reminder.dueDateComponents?.date
        self.reminder = reminder

        try addAlarms(from: reminder, prune: true)
    }

    func toReminder() throws -> EKReminder {
        guard self.hasReminder else { throw BethinkMeError("tried to access EKReminder before it was set") }
        self.reminder!.title = self.title
        self.reminder!.isCompleted = self.isCompleted
        self.reminder!.notes = self.notes
        self.reminder!.url = self.url
        if dueDate != nil {
            self.reminder!.dueDateComponents = Calendar.current.dateComponents(
                                                    [.day, .month, .year], from: self.dueDate!)
        } else {
            print("set em to nil")
            self.reminder!.dueDateComponents = nil
        }

        return self.reminder!
    }

    private func addAlarms(from reminder: EKReminder, prune: Bool = false) throws {
        if reminder.hasAlarms {
            for alarm in reminder.alarms! {
                if let existingAlarm = self.alarms.first(where: { $0 == alarm }) {
                    // we already have one, attach the EKAlarm
                    existingAlarm.baseAlarm = alarm
                } else {
                    // this is new, make a whole new instance
                    if alarm.absoluteDate != nil {
                        do {
                            try self.alarms.append(BethinkeryTimeAlarm.fromEKAlarm(alarm))
                        } catch {
                            throw BethinkMeError("failed to coerce EKAlarm to BethinkeryTimeAlarm",
                                                 from: error as NSError)
                        }
                    }
                    if alarm.structuredLocation != nil {
                        do {
                            try self.alarms.append(BethinkeryProximityAlarm.fromEKAlarm(alarm))
                        } catch {
                            throw BethinkMeError("failed to coerce EKAlarm to BethinkeryProximityAlarm",
                                                 from: error as NSError)
                        }
                    }
                }
            }
        }

        if prune {
            var deleteables: [Int] = []
            for (idx, alarm) in self.alarms.enumerated() where alarm.baseAlarm == nil {
                // we loaded this from storage but didn't find any current EKAlarms to attach
                // so we assume it's no longer valid
                modelContext?.delete(alarm)
                deleteables.append(idx)
            }
            self.alarms.remove(atOffsets: IndexSet(deleteables))
        }
    }
}

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
            if let alarm = lhs as? BethinkeryTimeAlarm {
                return alarm.time == rhs.absoluteDate
            }
        } else if rhs.structuredLocation != nil {
            if let alarm = lhs as? BethinkeryProximityAlarm {
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

@available(iOS 26.0, *)
@Model
final class BethinkeryTimeAlarm: BethinkeryAlarm {
    var time: Date

    init(id: String?, time: Date, baseAlarm: EKAlarm?) {
        self.time = time

        super.init(id: id, baseAlarm: baseAlarm)
    }

    static func fromEKAlarm(_ alarm: EKAlarm) throws -> BethinkeryTimeAlarm {
        guard alarm.absoluteDate != nil  else {
            throw BethinkMeError("tried to make a BethinkeryTimeAlarm from an EKAlarm with no time info")
        }

        return BethinkeryTimeAlarm(
            id: nil,
            time: alarm.absoluteDate!,
            baseAlarm: alarm
        )
    }
}

@available(iOS 26.0, *)
@Model
final class BethinkeryProximityAlarm: BethinkeryAlarm {
    var title: String
    var radius: Double
    var location: LatLng
    var type: AlarmProximityType

    init(id: String?, title: String, radius: Double, location: LatLng, type: AlarmProximityType, baseAlarm: EKAlarm?) {
        self.title = title
        self.radius = radius
        self.location = location
        self.type = type

        super.init(id: id, baseAlarm: baseAlarm)
    }

    static func fromEKAlarm(_ alarm: EKAlarm) throws -> BethinkeryProximityAlarm {
        guard alarm.structuredLocation?.geoLocation != nil  else {
            throw BethinkMeError("tried to make a BethinkeryProximityAlarm from an EKAlarm with no location info")
        }

        let loc = alarm.structuredLocation!

        return BethinkeryProximityAlarm(
            id: nil,
            title: loc.title ?? "Location",
            radius: loc.radius,
            location: LatLng(
                lat: loc.geoLocation!.coordinate.latitude,
                lng: loc.geoLocation!.coordinate.longitude),
            type: AlarmProximityType(rawValue: alarm.proximity.rawValue) ?? AlarmProximityType.nothing,
            baseAlarm: alarm
        )
    }
}

nonisolated struct LatLng: Codable, Hashable {
    var lat: Double
    var lng: Double
}
