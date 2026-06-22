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
        do {
            let reminder = EKReminder(eventStore: sharedModel.eventStore)
            reminder.title = createCommand.title
            reminder.isCompleted = createCommand.isCompleted
            reminder.calendar = try list.toCalendar()

            try sharedModel.eventStore.save(reminder, commit: true)

            let newBethinkery = try Bethinkery(reminder: reminder, list: list)
            sharedModel.modelContext.insert(newBethinkery)
            list.bethinkeries.insert(newBethinkery, at: 0)
            sharedModel.resetOrdinals()
        } catch {
            throw BethinkMeError("failed to create new Bethinkery", from: error as NSError)
        }
    }

    func update(_ bethinkery: Bethinkery, with updateCommand: EditBethinkery) throws {
        bethinkery.title = updateCommand.title
        bethinkery.isCompleted = updateCommand.isCompleted
        bethinkery.freshlyCompleted = updateCommand.freshlyCompleted
        bethinkery.notes = updateCommand.notes
        bethinkery.url = updateCommand.url

        do {
            try sharedModel.eventStore.save(bethinkery.toReminder(), commit: true)
        } catch {
            throw BethinkMeError("failed to commit Bethinkery update", from: error as NSError)
        }
    }

    func delete(_ bethinkery: Bethinkery) throws {
        do {
            try sharedModel.eventStore.remove(bethinkery.toReminder(), commit: true)
            sharedModel.modelContext.delete(bethinkery)
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
        guard from.count == 1 else {
            throw BethinkMeError("invalid number of items sent to move: \(from.count)")
        }
        var tmpBethinkeries = sharedModel.bethinkeries.filter({ $0.list.id == list.id })
        tmpBethinkeries.move(fromOffsets: from, toOffset: to)

        // only reordinalize stuff in the affected range to limit weird moving of hidden items
        for (idx, bethinkery) in tmpBethinkeries[...(max(from.first!, to))].enumerated() {
            bethinkery.ordinal = idx
        }
    }

    func moveBethinkery(_ bethinkery: Bethinkery, to: BethinkeryList) throws {
        let currentList = bethinkery.list
        guard currentList != to else { return }

        do {
            // TODO: ensure we strip existing list-applied rules like location/time alerts, add new ones
            let clonedBethinkery = EditBethinkery.fromBethinkery(bethinkery)
            try delete(bethinkery)
            try create(from: clonedBethinkery, list: to)
        } catch {
            throw BethinkMeError("failed to move Bethinkery", from: error as NSError)
        }
    }

    func addAlarm(_ newAlarm: BethinkeryAlarm, to bethinkery: Bethinkery) throws {
        guard newAlarm.baseAlarm == nil else {
            throw BethinkMeError("tried to add a new alarm that was already associated with an EKAlarm")
        }
        let newBaseAlarm: EKAlarm?
        if newAlarm is AbsoluteTimeAlarm {
            guard let newTimeAlarm = newAlarm as? AbsoluteTimeAlarm else {
                throw BethinkMeError("unable to coerce BethinkeryAlarm to BethinkeryAbsoluteTimeAlarm when saving")
            }
            if !newTimeAlarm.isAllDay {
                newBaseAlarm = EKAlarm(absoluteDate: newTimeAlarm.time)
            } else {
                newBaseAlarm = nil
            }
        } else if newAlarm is RelativeTimeAlarm {
            guard let newTimeAlarm = newAlarm as? RelativeTimeAlarm else {
                throw BethinkMeError("unable to coerce BethinkeryAlarm to BethinkeryRelativeTimeAlarm when saving")
            }
            newBaseAlarm = EKAlarm(relativeOffset: newTimeAlarm.offset)
        } else if newAlarm is ProximityAlarm {
            guard let newProxAlarm = newAlarm as? ProximityAlarm else {
                throw BethinkMeError("unable to coerce BethinkeryAlarm to BethinkeryProximityAlarm when saving")
            }
            let location = EKStructuredLocation(title: newProxAlarm.title)
            location.geoLocation = CLLocation(latitude: newProxAlarm.location.lat, longitude: newProxAlarm.location.lng)
            location.radius = newProxAlarm.radius
            newBaseAlarm = EKAlarm(relativeOffset: 0)
            newBaseAlarm!.structuredLocation = location
            newBaseAlarm!.proximity = switch newProxAlarm.type {
                case .enter: .enter
                case .leave: .leave
                case .nothing: .none
            }
        } else {
            throw BethinkMeError("tried to add a new alarm of unrecognized type")
        }

        do {
            newAlarm.baseAlarm = newBaseAlarm
            bethinkery.alarms.append(newAlarm)
            sharedModel.modelContext.insert(newAlarm)
            let reminder = try bethinkery.toReminder()
            if newBaseAlarm != nil {
                reminder.addAlarm(newBaseAlarm!)
            }
            try sharedModel.eventStore.save(reminder, commit: true)
        } catch {
            throw BethinkMeError("failed to add alarm to Bethinkery", from: error as NSError)
        }
    }

    func removeAlarm(_ alarm: BethinkeryAlarm, from bethinkery: Bethinkery) throws {
        do {
            bethinkery.alarms.removeAll(where: { $0.id == alarm.id })
            sharedModel.modelContext.delete(alarm)

            let reminder = try bethinkery.toReminder()
            if alarm.baseAlarm != nil {
                reminder.removeAlarm(alarm.baseAlarm!)
            }
            try sharedModel.eventStore.save(reminder, commit: true)
        } catch {
            throw BethinkMeError("failed to delete alarm", from: error as NSError)
        }
    }
}
