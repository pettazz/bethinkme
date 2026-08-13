import EventKit
import SwiftData
import SwiftUI


@Model
final class Bethinkery: Equatable, Identifiable {
    @AppStorage(SettingsKey.dedupeCaseSensitive.rawValue)
    @Transient private var dedupeCaseSensitive: Bool = kDedupeCaseSensitiveDefault

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

    var hasNotes: Bool {
        if let notes = self.notes {
            return !notes.isEmpty
        }
        return false
    }
    var hasUrl: Bool { return self.url != nil }
    var hasAlarms: Bool { return !self.alarms.isEmpty }
    var hasAbsoluteTimeAlarm: Bool { return self.alarms.contains(where: { $0.kind == .absoluteTimeAlarm }) }
    var hasRelativeTimeAlarm: Bool { return self.alarms.contains(where: { $0.kind == .relativeTimeAlarm }) }
    var hasProximityAlarm: Bool { return self.alarms.contains(where: { $0.kind == .proximityAlarm }) }


    init(id: String,
         list: BethinkeryList,
         title: String,
         isCompleted: Bool,
         notes: String?,
         url: URL?) {
        self.id = id
        self.list = list
        self.title = title
        self.isCompleted = isCompleted
        self.notes = notes
        self.url = url
    }

    // used when creating a new Bethinkery from an existing EKReminder
    convenience init(reminder: EKReminder, list: BethinkeryList) throws {
        self.init(
            id: reminder.calendarItemIdentifier,
            list: list,
            title: reminder.title,
            isCompleted: reminder.isCompleted,
            notes: reminder.notes,
            url: reminder.url)

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

        try loadAlarms(from: reminder)
    }

    func apply(to reminder: EKReminder) throws {
        reminder.title = self.title
        reminder.isCompleted = self.isCompleted
        reminder.notes = self.notes
        reminder.url = self.url
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
            reminder.dueDateComponents = dateComps
            reminder.startDateComponents = dateComps
        } else {
            reminder.dueDateComponents = nil
            reminder.startDateComponents = nil
        }
    }

    func updateID(to newID: String) {
        let oldSynthID = "synth-\(self.id)"
        self.id = newID
        for alarm in self.alarms where alarm.id == oldSynthID {
            alarm.id = "synth-\(newID)"
        }
    }

    func isDuplicate(of bethinkery: Bethinkery) -> Bool {
        let titleText = dedupeCaseSensitive ? title : title.lowercased()
        let compareText = dedupeCaseSensitive ? bethinkery.title : bethinkery.title.lowercased()

        guard titleText == compareText &&
              notes == bethinkery.notes &&
              // TODO: url field is going away, priority will replace it
              alarms.count == bethinkery.alarms.count
            else { return false }

        var checkAlarms = bethinkery.alarms
        for alarm in alarms {
            guard let idx = checkAlarms.firstIndex(where: { alarm.isDuplicate(of: $0) })
                else { return false }
            checkAlarms.remove(at: idx)
        }
        return true
    }

    private func loadAlarms(from reminder: EKReminder) throws {
        var knownAlarmIDs = Set<String>()

        for alarm in reminder.alarms ?? [] {
            // we already have one, track it
            if let existingAlarm = self.alarms.first(where: { $0 == alarm }) {
                knownAlarmIDs.insert(existingAlarm.id)
            } else {
                // this is new, make a whole new instance
                do {
                    if let newAlarm = try BethinkeryAlarm.fromEKAlarm(alarm) {
                        self.alarms.append(newAlarm)
                        knownAlarmIDs.insert(newAlarm.id)
                    }
                } catch {
                    throw BethinkMeError("failed to coerce EKAlarm to BethinkeryAlarm",
                                         from: error as NSError)
                }
            }
        }

        let deleteables = self.alarms.filter({ !knownAlarmIDs.contains($0.id) && !$0.representsDueDate })
        self.alarms.removeAll(where: { deleteables.map(\.id).contains($0.id) })
        for alarm in deleteables {
            modelContext?.delete(alarm)
        }

        self.synthesizeDueDateAlarm(from: reminder)
    }

    private func synthesizeDueDateAlarm(from reminder: EKReminder) {
        let synthID = "synth-\(self.id)"

        func removeSynth() {
            guard let synth = alarms.dueDateAlarm else { return }
            alarms.removeAll { $0.id == synth.id }
            modelContext?.delete(synth)
        }

        // we have a real due date alarm, no need
        if (alarms.contains { $0.kind == .absoluteTimeAlarm && !$0.representsDueDate }) {
            removeSynth()
            return
        }

        // no due date
        guard let due = reminder.dueDateComponents else {
            removeSynth()
            return
        }

        let isAllDay = due.hour == nil && due.minute == nil
        guard let ddDate = Calendar.current.date(from: due) else {
            removeSynth()
            return
        }

        // update existing or add
        if let synth = alarms.first(where: \.representsDueDate) {
            synth.time = ddDate
            synth.isAllDay = isAllDay
        } else {
            alarms.append(.absoluteTime(id: synthID, time: ddDate, isAllDay: isAllDay))
        }
    }
}
