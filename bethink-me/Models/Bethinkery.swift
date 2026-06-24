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
        self.reminder = reminder

        try addAlarms(from: reminder)
    }

    func toReminder() throws -> EKReminder {
        guard self.hasReminder else { throw BethinkMeError("tried to access EKReminder before it was set") }
        self.reminder!.title = self.title
        self.reminder!.isCompleted = self.isCompleted
        self.reminder!.notes = self.notes
        self.reminder!.url = self.url
        if let implicitDueDate = self.alarms.earliestAlarm {
            let dateComps = Calendar.current.dateComponents(
                implicitDueDate.isAllDay
                    ? [.day, .month, .year]
                    : [.day, .month, .year, .hour, .minute],
                from: self.alarms.earliestAlarm!.time
            )
            self.reminder!.dueDateComponents = dateComps
            self.reminder!.startDateComponents = dateComps
        } else {
            self.reminder!.dueDateComponents = nil
            self.reminder!.startDateComponents = nil
        }

        return self.reminder!
    }

    private func addAlarms(from reminder: EKReminder) throws {
        if reminder.hasAlarms {
            for alarm in reminder.alarms! {
                if let existingAlarm = self.alarms.first(where: { $0 == alarm }) {
                    // we already have one, attach the EKAlarm
                    existingAlarm.baseAlarm = alarm
                } else {
                    // this is new, make a whole new instance
                    if alarm.absoluteDate != nil {
                        do {
                            try self.alarms.append(AbsoluteTimeAlarm.fromEKAlarm(alarm))
                        } catch {
                            throw BethinkMeError("failed to coerce EKAlarm to BethinkeryAbsoluteTimeAlarm",
                                                 from: error as NSError)
                        }
                    }
                    if alarm.relativeOffset != 0 {
                        do {
                            try self.alarms.append(RelativeTimeAlarm.fromEKAlarm(alarm))
                        } catch {
                            throw BethinkMeError("failed to coerce EKAlarm to BethinkeryRelativeTimeAlarm",
                                                 from: error as NSError)
                        }
                    }
                    if alarm.structuredLocation != nil {
                        do {
                            try self.alarms.append(ProximityAlarm.fromEKAlarm(alarm))
                        } catch {
                            throw BethinkMeError("failed to coerce EKAlarm to BethinkeryProximityAlarm",
                                                 from: error as NSError)
                        }
                    }
                }
            }
        }

        var deleteables: [Int] = []
        for (idx, alarm) in self.alarms.enumerated() where alarm.baseAlarm == nil {
            // we loaded this from storage but didn't find any current EKAlarms to attach
            // so we assume it's no longer valid
            modelContext?.delete(alarm)
            deleteables.append(idx)
        }
        self.alarms.remove(atOffsets: IndexSet(deleteables))

        self.synthesizeDueDateAlarm(from: reminder)
    }

    private func synthesizeDueDateAlarm(from reminder: EKReminder) {
        if reminder.dueDateComponents != nil {
            let due = reminder.dueDateComponents!
            if !(self.alarms.contains { alarm in
                if let timeAlarm = alarm as? AbsoluteTimeAlarm {
                    let alarmComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                                     from: timeAlarm.time)
                    return due.year == alarmComps.year
                        && due.month == alarmComps.month
                        && due.day == alarmComps.day
                } else {
                    return false
                }
            }) {
                let ddDate = Calendar.current.date(from: reminder.dueDateComponents!)
                if ddDate != nil {
                    let ddAlarm = AbsoluteTimeAlarm(time: ddDate!, isAllDay: true)
                    self.alarms.append(ddAlarm)
                }
            }
        }
    }
}
