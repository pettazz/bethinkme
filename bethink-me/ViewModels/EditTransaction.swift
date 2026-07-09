import EventKit
import SwiftData


@MainActor
final class EditTransaction {
    private let eventStore: EKEventStore
    private let modelContext: ModelContext

    private var calendarCache: [String: EKCalendar] = [:]
    private var reminderCache: [String: EKReminder] = [:]

    private var isDirty = false


    init(eventStore: EKEventStore, modelContext: ModelContext) {
        self.eventStore = eventStore
        self.modelContext = modelContext
    }

    func newReminder(on calendar: EKCalendar) throws -> EKReminder {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar

        try stage(reminder)
        try commit()

        return reminder
    }

    func liveCalendar(for list: BethinkeryList) throws -> EKCalendar {
        let calendar: EKCalendar

        if let cachedCalendar = calendarCache[list.id] {
            calendar = cachedCalendar
        } else {
            guard let fetched = eventStore.calendar(withIdentifier: list.id) else {
                throw BethinkMeError("cannot find EKCalendar for BethinkeryList \(list.id)")
            }
            calendar = fetched
            calendarCache[list.id] = calendar
        }

        list.apply(to: calendar)

        return calendar
    }

    func liveReminder(for bethinkery: Bethinkery) throws -> EKReminder {
        let reminder: EKReminder

        if let cachedReminder = reminderCache[bethinkery.id] {
            reminder = cachedReminder
        } else {
            guard let fetched = eventStore.calendarItem(withIdentifier: bethinkery.id) as? EKReminder else {
                throw BethinkMeError("cannot find EKReminder for Bethinkery \(bethinkery.id)")
            }
            reminder = fetched
            reminderCache[bethinkery.id] = reminder
        }

        try bethinkery.apply(to: reminder)

        return reminder
    }

    func stage(_ reminder: EKReminder) throws {
        try eventStore.save(reminder, commit: false)
        isDirty = true
    }

    func stage(_ calendar: EKCalendar) throws {
        try eventStore.saveCalendar(calendar, commit: false)
        isDirty = true
    }

    func stageRemove(_ reminder: EKReminder) throws {
        try eventStore.remove(reminder, commit: false)
        isDirty = true
    }

    func stageRemove(_ calendar: EKCalendar) throws {
        try eventStore.removeCalendar(calendar, commit: false)
        isDirty = true
    }

    func insertModel(_ model: any PersistentModel) {
        modelContext.insert(model)
    }

    func deleteModel(_ model: any PersistentModel) {
        modelContext.delete(model)
    }

    func commit() throws {
        do {
            if isDirty {
                try eventStore.commit()
                isDirty = false
            }
            try modelContext.save()
        } catch {
            throw BethinkMeError("failed to commit transaction", from: error as NSError)
        }
    }

    func rollback() {
        if isDirty {
            eventStore.reset()
        }
        modelContext.rollback()

        calendarCache.removeAll()
        reminderCache.removeAll()
    }
}
