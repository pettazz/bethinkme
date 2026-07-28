import EventKit
import SwiftData


@MainActor
@Observable
final class SharedViewModel {
    let modelContext: ModelContext
    let syncCoordinator = SyncCoordinator()
    var syncStatus: SyncStatus = .ok
    nonisolated final let eventStore = EKEventStore()

    private var eventStoreChangedTask: Task<Void, Never>?

    var hasAccess: Bool = false
    var showCompleted: Bool = false

    private var bethinkeryListsCache: [BethinkeryList] = []
    private var bethinkeriesCache: [Bethinkery] = []
    private var unfilteredBethinkeriesCache: [Bethinkery] = []

    var bethinkeryLists: [BethinkeryList] { bethinkeryListsCache }


    init(modelContext: ModelContext) async {
        modelContext.autosaveEnabled = false
        self.modelContext = modelContext
        self.hasAccess = await checkPermissions()
        self.reload()
    }

    func startEventStoreObserver() {
        guard eventStoreChangedTask == nil else { return }
        eventStoreChangedTask = Task {
            for await _ in NotificationCenter.default.notifications(
                named: .EKEventStoreChanged,
                object: nil) {
                self.syncCoordinator.requestSync(reason: .EKChanged)
            }
        }
    }

    func checkPermissions() async -> Bool {
        hasAccess = (try? await eventStore.requestFullAccessToReminders()) ?? false
        return hasAccess
    }

    func resetOrdinals() {
        for (idx, list) in bethinkeryLists.enumerated() {
            list.ordinal = idx

            for (iidx, bethinkery) in list.orderedBethinkeries.enumerated() {
                bethinkery.ordinal = iidx
                bethinkery.freshlyCompleted = false // hehehehe side effects
            }
        }
    }

    private func fetchAll() throws {
        let bethinkeryListsCacheUpdate = try modelContext.fetch(FetchDescriptor(
            sortBy: [.init(\BethinkeryList.ordinal)]))

        let bethinkeriesCacheUpdate = try modelContext.fetch(FetchDescriptor(
            predicate: #Predicate<Bethinkery> { bethinkery in
                return (showCompleted || !bethinkery.isCompleted) || bethinkery.freshlyCompleted
            },
            sortBy: [.init(\Bethinkery.ordinal)]))

        let unfilteredBethinkeriesCacheUpdate = try modelContext.fetch(FetchDescriptor(
            sortBy: [.init(\Bethinkery.ordinal)]))

        bethinkeryListsCache = bethinkeryListsCacheUpdate
        bethinkeriesCache = bethinkeriesCacheUpdate
        unfilteredBethinkeriesCache = unfilteredBethinkeriesCacheUpdate
    }

    func reload() {
        do {
            try fetchAll()
            ErrorState.instance.clear()
        } catch {
            ErrorReporter().report(BethinkMeError("failed to fetch from model context", from: error as NSError),
                                   retry: { try self.fetchAll() })
        }
    }

    func saveContext() throws {
        try modelContext.save()
        syncCoordinator.iJustMadeAChange()
        reload()
    }

    func withTransaction<T>(_ action: (EditTransaction) throws -> T) throws -> T {
        let transaction = EditTransaction(eventStore: eventStore, modelContext: modelContext)

        do {
            let result = try action(transaction)
            try transaction.commit()
            syncCoordinator.iJustMadeAChange()
            reload()
            return result
        } catch {
            transaction.rollback()
            reload()
            throw error
        }
    }

    private func makeEKAlarm(for alarm: BethinkeryAlarm) throws -> EKAlarm? {
        let newEKAlarm: EKAlarm?

        switch alarm.kind {
            case .absoluteTimeAlarm:
                if !alarm.isAllDay {
                    guard let alarmTime = alarm.time else {
                        throw BethinkMeError("tried to create absoluteTime BethinkeryAlarm from template missing time")
                    }
                    newEKAlarm = EKAlarm(absoluteDate: alarmTime)
                } else {
                    newEKAlarm = nil
                }
            case .relativeTimeAlarm:
                newEKAlarm = EKAlarm(relativeOffset: alarm.offset)
            case .proximityAlarm:
                let location = EKStructuredLocation(title: alarm.title)
                location.geoLocation = CLLocation(latitude: alarm.location.lat, longitude: alarm.location.lng)
                location.radius = alarm.radius
                let newBaseAlarm = EKAlarm(relativeOffset: 0)
                newBaseAlarm.structuredLocation = location
                newBaseAlarm.proximity = switch alarm.proximityType {
                    case .enter: .enter
                    case .leave: .leave
                    case .nothing: .none
                }
                newEKAlarm = newBaseAlarm
        }

        return newEKAlarm
    }

    func addAlarm(_ template: any BethinkeryAlarmTemplate,
                  to bethinkery: Bethinkery,
                  within transaction: EditTransaction) throws {
        let newAlarm: BethinkeryAlarm = template.toModel()

        do {
            let newBaseAlarm: EKAlarm? = try makeEKAlarm(for: newAlarm)
            bethinkery.alarms.append(newAlarm)
            transaction.insertModel(newAlarm)

            let reminder: EKReminder = try transaction.liveReminder(for: bethinkery)
            if let newBaseAlarm {
                reminder.addAlarm(newBaseAlarm)
            }
            try transaction.stage(reminder)
        } catch {
            throw BethinkMeError("failed to add alarm to Bethinkery", from: error as NSError)
        }
    }

    func removeAlarm(_ alarm: BethinkeryAlarm,
                     from bethinkery: Bethinkery,
                     within transaction: EditTransaction) throws {
        do {
            bethinkery.alarms.removeAll(where: { $0.id == alarm.id })
            transaction.deleteModel(alarm)

            if !(alarm.kind == .absoluteTimeAlarm && alarm.isAllDay) {
                let reminder = try transaction.liveReminder(for: bethinkery)
                if let ekAlarm = reminder.alarms?.first(where: { alarm == $0 }) {
                    reminder.removeAlarm(ekAlarm)
                }
                try transaction.stage(reminder)
            }
        } catch {
            throw BethinkMeError("failed to delete alarm", from: error as NSError)
        }
    }

    func replaceAlarms(on bethinkery: Bethinkery,
                       with templates: [any BethinkeryAlarmTemplate],
                       within transaction: EditTransaction) throws {
        do {
            let oldAlarms = bethinkery.alarms

            for oldAlarm in oldAlarms {
                try removeAlarm(oldAlarm, from: bethinkery, within: transaction)
            }
            for newAlarm in templates {
                try addAlarm(newAlarm, to: bethinkery, within: transaction)
            }

            try transaction.stage(transaction.liveReminder(for: bethinkery))
        } catch {
            throw BethinkMeError("failed to save Bethinkery after replacing alarms", from: error as NSError)
        }
    }
}
