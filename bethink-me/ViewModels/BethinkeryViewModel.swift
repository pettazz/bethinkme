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

    func create(from createCommand: EditBethinkery,
                list: BethinkeryList,
                sortedBy: BethinkerySorting = .custom) throws -> Bethinkery {
        do {
            return try sharedModel.withTransaction { transaction in
                let reminder = try transaction.newReminder(on: try transaction.liveCalendar(for: list))

                reminder.title = createCommand.title
                reminder.isCompleted = createCommand.isCompleted

                let newBethinkery = try Bethinkery(reminder: reminder, list: list)
                transaction.insertModel(newBethinkery)

                for alarm in list.alarmTemplates.compactMap({ $0.toTemplate(newInstance: true) }) {
                    try sharedModel.addAlarm(alarm, to: newBethinkery, within: transaction)
                }

                list.bethinkeries.append(newBethinkery)
                sharedModel.resetOrdinals(sortedBy: sortedBy)

                try transaction.stage(transaction.liveReminder(for: newBethinkery))

                return newBethinkery
            }
        } catch {
            throw BethinkMeError("failed to create new Bethinkery", from: error as NSError)
        }
    }

    func update(_ bethinkery: Bethinkery, with updateCommand: EditBethinkery) throws {
        guard bethinkery.modelContext != nil else {
            throw BethinkMeError("lost model context for Bethinkery during edit")
        }
        do {
            try sharedModel.withTransaction { transaction in
                bethinkery.title = updateCommand.title
                bethinkery.isCompleted = updateCommand.isCompleted
                bethinkery.freshlyCompleted = updateCommand.freshlyCompleted
                bethinkery.notes = updateCommand.notes
                bethinkery.priority = updateCommand.priority

                let existingAlarmIDs = Set(bethinkery.alarms.map(\.id))
                let updatedAlarmIDs = Set(updateCommand.alarms.map(\.id))

                for alarm in bethinkery.alarms where !updatedAlarmIDs.contains(alarm.id) {
                    try sharedModel.removeAlarm(alarm, from: bethinkery, within: transaction)
                }
                for alarm in updateCommand.alarms where !existingAlarmIDs.contains(alarm.id) {
                    try sharedModel.addAlarm(alarm, to: bethinkery, within: transaction)
                }

                try transaction.stage(transaction.liveReminder(for: bethinkery))
            }
        } catch {
            throw BethinkMeError("failed to update Bethinkery", from: error as NSError)
        }
    }

    func delete(_ bethinkery: Bethinkery) throws {
        guard bethinkery.modelContext != nil else {
            throw BethinkMeError("lost model context for Bethinkery during delete")
        }
        do {
            try sharedModel.withTransaction { transaction in
                try transaction.stageRemove(transaction.liveReminder(for: bethinkery))
                transaction.deleteModel(bethinkery)
            }
        } catch {
            throw BethinkMeError("failed to delete Bethinkery", from: error as NSError)
        }
    }

    func delete(_ bethinkeries: [Bethinkery]) throws {
        do {
            try sharedModel.withTransaction { transaction in
                for bethinkery in bethinkeries {
                    guard bethinkery.modelContext != nil else {
                        throw BethinkMeError("lost model context for Bethinkery during delete")
                    }
                    try transaction.stageRemove(transaction.liveReminder(for: bethinkery))
                    transaction.deleteModel(bethinkery)
                }
            }
        } catch {
            throw BethinkMeError("failed to delete list of Bethinkeries", from: error as NSError)
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

    func moveBethinkeryPosition(from: IndexSet,
                                to: Int,
                                list: BethinkeryList,
                                currentSorting: BethinkerySorting = .custom) throws {
        guard from.count == 1 else {
            throw BethinkMeError("invalid number of items sent to move: \(from.count)")
        }
        try sharedModel.withTransaction { _ in
            var tmpBethinkeries = list.visibleBethinkeries(showCompleted: sharedModel.showCompleted,
                                                           sortedBy: currentSorting)
            tmpBethinkeries.move(fromOffsets: from, toOffset: to)

            for (idx, bethinkery) in tmpBethinkeries.enumerated() {
                bethinkery.ordinal = idx
            }
            sharedModel.resetOrdinals(except: list, sortedBy: currentSorting)
        }
    }

    func moveBethinkery(_ bethinkery: Bethinkery, to list: BethinkeryList, inheritListAlarms: Bool = true) throws {
        let currentList = bethinkery.list
        guard currentList != list else { return }

        do {
            try sharedModel.withTransaction { transaction in
                bethinkery.ordinal = -1
                bethinkery.list = list
                let reminder = try transaction.liveReminder(for: bethinkery)
                reminder.calendar = try transaction.liveCalendar(for: list)

                if inheritListAlarms {
                    try sharedModel.replaceAlarms(on: bethinkery,
                                                  with: list.alarmTemplates.compactMap(
                                                    { $0.toTemplate(newInstance: true) }),
                                                  within: transaction)
                }

                try transaction.stage(reminder)
                transaction.rememberToReconcileID(of: bethinkery, against: reminder)
                sharedModel.resetOrdinals()
            }
        } catch {
            throw BethinkMeError("failed to move Bethinkery", from: error as NSError)
        }
    }
}
