import EventKit
import SwiftData
import SwiftUI


@MainActor
@Observable
final class BethinkeryViewModel {
    private let sharedModel: SharedViewModel


    init(sharedModel: SharedViewModel) {
        self.sharedModel = sharedModel
    }

    func create(from createCommand: EditBethinkery, list: BethinkeryList) throws {
        let reminder = EKReminder(eventStore: sharedModel.eventStore)
        reminder.title = createCommand.title
        reminder.isCompleted = createCommand.isCompleted
        reminder.calendar = try list.toCalendar(in: sharedModel.eventStore)

        do {
            try sharedModel.eventStore.save(reminder, commit: true)

            let newBethinkery = try Bethinkery(reminder: reminder, list: list)
            sharedModel.modelContext.insert(newBethinkery)
            try sharedModel.saveContext()

            for alarm in list.alarmTemplates.compactMap({ $0.toTemplate(newInstance: true) }) {
                try sharedModel.addAlarm(alarm, to: newBethinkery)
            }

            try sharedModel.eventStore.save(newBethinkery.toReminder(in: sharedModel.eventStore), commit: true)
            try sharedModel.saveContext()

            list.bethinkeries.insert(newBethinkery, at: 0)
            sharedModel.resetOrdinals()

        } catch {
            throw BethinkMeError("failed to create new Bethinkery", from: error as NSError)
        }
    }

    func update(_ bethinkery: Bethinkery, with updateCommand: EditBethinkery) throws {
        guard bethinkery.modelContext != nil else {
            throw BethinkMeError("lost model context for Bethinkery during edit")
        }
        bethinkery.title = updateCommand.title
        bethinkery.isCompleted = updateCommand.isCompleted
        bethinkery.freshlyCompleted = updateCommand.freshlyCompleted
        bethinkery.notes = updateCommand.notes
        bethinkery.url = updateCommand.url

        let existingAlarmIDs = Set(bethinkery.alarms.map(\.id))
        let updatedAlarmIDs = Set(updateCommand.alarms.map(\.id))

        for alarm in bethinkery.alarms where !updatedAlarmIDs.contains(alarm.id) {
            try sharedModel.removeAlarm(alarm, from: bethinkery)
        }
        for alarm in updateCommand.alarms where !existingAlarmIDs.contains(alarm.id) {
            try sharedModel.addAlarm(alarm, to: bethinkery)
        }

        do {
            try sharedModel.eventStore.save(bethinkery.toReminder(in: sharedModel.eventStore), commit: true)
            try sharedModel.saveContext()
        } catch {
            throw BethinkMeError("failed to commit Bethinkery update", from: error as NSError)
        }
    }

    func delete(_ bethinkery: Bethinkery) throws {
        guard bethinkery.modelContext != nil else {
            throw BethinkMeError("lost model context for Bethinkery during delete")
        }
        do {
            try sharedModel.eventStore.remove(bethinkery.toReminder(in: sharedModel.eventStore), commit: true)
            sharedModel.modelContext.delete(bethinkery)
            try sharedModel.saveContext()
        } catch {
            throw BethinkMeError("failed to delete Bethinkery", from: error as NSError)
        }
    }

    func toggleCompleted(_ bethinkery: Bethinkery) throws {
        let updatedBethinkery = EditBethinkery.fromBethinkery(bethinkery)
        updatedBethinkery.isCompleted.toggle()
        updatedBethinkery.freshlyCompleted = updatedBethinkery.isCompleted

        do {
            try update(bethinkery, with: updatedBethinkery)
        } catch {
            throw BethinkMeError("failed to toggle complete", from: error as NSError)
        }
    }

    func moveBethinkeryPosition(from: IndexSet, to: Int, list: BethinkeryList) throws {
        guard from.count == 1, let firstIdx = from.first else {
            throw BethinkMeError("invalid number of items sent to move: \(from.count)")
        }
        var tmpBethinkeries = sharedModel.bethinkeries.filter({ $0.list.id == list.id })
        tmpBethinkeries.move(fromOffsets: from, toOffset: to)

        // only reordinalize stuff in the affected range to limit weird moving of hidden items
        for (idx, bethinkery) in tmpBethinkeries[..<(max(firstIdx, to))].enumerated() {
            bethinkery.ordinal = idx
        }
        try sharedModel.saveContext()
    }

    func moveBethinkery(_ bethinkery: Bethinkery, to list: BethinkeryList, inheritListAlarms: Bool = true) throws {
        let currentList = bethinkery.list
        guard currentList != list else { return }

        do {
            let reminder = try bethinkery.toReminder(in: sharedModel.eventStore)
            bethinkery.list.bethinkeries.removeAll(where: { $0.id == bethinkery.id })

            bethinkery.ordinal = -1
            bethinkery.list = list
            bethinkery.list.bethinkeries.insert(bethinkery, at: 0)
            reminder.calendar = try list.toCalendar(in: sharedModel.eventStore)

            if inheritListAlarms {
                try sharedModel.replaceAlarms(on: bethinkery,
                                              with: list.alarmTemplates.compactMap(
                                                { $0.toTemplate(newInstance: true) }))
            }

            try sharedModel.eventStore.save(reminder, commit: true)
            try sharedModel.saveContext()
        } catch {
            throw BethinkMeError("failed to move Bethinkery", from: error as NSError)
        }
    }
}
