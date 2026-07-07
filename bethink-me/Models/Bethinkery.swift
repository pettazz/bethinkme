import EventKit
import SwiftData
import SwiftUI


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
    @Relationship(deleteRule: .cascade)
    var alarms: [BethinkeryAlarm] = []
    @Transient var reminder: EKReminder?

    var hasNotes: Bool { return self.notes != nil && !self.notes!.isEmpty }
    var hasUrl: Bool { return self.url != nil }
    var hasReminder: Bool { return self.reminder != nil }
    var hasAlarms: Bool { return !self.alarms.isEmpty }
    var hasAbsoluteTimeAlarm: Bool { return self.alarms.contains(where: { $0.kind == .absoluteTimeAlarm }) }
    var hasRelativeTimeAlarm: Bool { return self.alarms.contains(where: { $0.kind == .relativeTimeAlarm }) }
    var hasProximityAlarm: Bool { return self.alarms.contains(where: { $0.kind == .proximityAlarm }) }


    init(id: String,
         list: BethinkeryList,
         title: String,
         isCompleted: Bool,
         notes: String?,
         url: URL?,
         reminder: EKReminder) {
        self.id = id
        self.list = list
        self.title = title
        self.isCompleted = isCompleted
        self.notes = notes
        self.url = url
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
            reminder: reminder)

        try loadAlarms(from: reminder)
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
        self.reminder = reminder

        try loadAlarms(from: reminder)
    }

    func toReminder() throws -> EKReminder {
        guard self.hasReminder else { throw BethinkMeError("tried to access EKReminder before it was set") }
        self.reminder!.title = self.title
        self.reminder!.isCompleted = self.isCompleted
        self.reminder!.notes = self.notes
        self.reminder!.url = self.url
        if let implicitDueDate = self.alarms.earliestAlarm {
            guard let implicitTime = implicitDueDate.time else {
                throw BethinkMeError("Bethinkery with implicit Due Date has no Time value")
            }
            let dateComps = Calendar.current.dateComponents(
                implicitDueDate.isAllDay
                    ? [.day, .month, .year]
                    : [.day, .month, .year, .hour, .minute],
                from: implicitTime
            )
            self.reminder!.dueDateComponents = dateComps
            self.reminder!.startDateComponents = dateComps
        } else {
            self.reminder!.dueDateComponents = nil
            self.reminder!.startDateComponents = nil
        }

        return self.reminder!
    }

    private func loadAlarms(from reminder: EKReminder) throws {
        if reminder.hasAlarms {
            for alarm in reminder.alarms! {
                if let existingAlarm = self.alarms.first(where: { $0 == alarm }) {
                    // we already have one, attach the EKAlarm
                    existingAlarm.baseAlarm = alarm
                } else {
                    // this is new, make a whole new instance
                    do {
                        if let newAlarm = try BethinkeryAlarm.fromEKAlarm(alarm) {
                            self.alarms.append(newAlarm)
                        }
                    } catch {
                        throw BethinkMeError("failed to coerce EKAlarm to BethinkeryAlarm",
                                             from: error as NSError)
                    }
                }
            }
        }

        let deleteables = self.alarms.filter({ $0.baseAlarm == nil })
        self.alarms.removeAll(where: { $0.baseAlarm == nil })
        for alarm in deleteables {
            modelContext?.delete(alarm)
        }

        self.synthesizeDueDateAlarm(from: reminder)
    }

    private func synthesizeDueDateAlarm(from reminder: EKReminder) {
        guard let due = reminder.dueDateComponents else { return }

        if !(self.alarms.contains { alarm in
            guard alarm.kind == .absoluteTimeAlarm, let alarmTime = alarm.time else { return false }

            let alarmComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                             from: alarmTime)
            return due.year == alarmComps.year
                && due.month == alarmComps.month
                && due.day == alarmComps.day

        }) {
            if let ddDate = Calendar.current.date(from: due) {
                let ddAlarm: BethinkeryAlarm = .absoluteTime(time: ddDate, isAllDay: true)
                self.alarms.append(ddAlarm)
            }
        }
    }
}
