import EventKit
import SwiftData


@MainActor
@Observable
final class SharedViewModel {
    let modelContext: ModelContext
    let syncCoordinator = SyncCoordinator()
    nonisolated final let eventStore = EKEventStore()

    private var eventStoreChangedTask: Task<Void, Never>?

    var hasAccess: Bool = false
    var showCompleted: Bool = false

    private var bethinkeryListsCache: [BethinkeryList] = []
    private var bethinkeriesCache: [Bethinkery] = []
    private var unfilteredBethinkeriesCache: [Bethinkery] = []

    var bethinkeryLists: [BethinkeryList] { bethinkeryListsCache }
    var bethinkeries: [Bethinkery] { bethinkeriesCache }
    var unfilteredBethinkeries: [Bethinkery] { unfilteredBethinkeriesCache }


    init(modelContext: ModelContext) async {
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
                await self.syncCoordinator.requestSync(reason: .EKChanged)
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

            for (iidx, bethinkery) in unfilteredBethinkeries.enumerated()
                .filter({ $0.1.list.id == list.id }) {
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

    func addAlarm(_ newAlarm: BethinkeryAlarm, to bethinkery: Bethinkery) throws {
        guard newAlarm.baseAlarm == nil else {
            throw BethinkMeError("tried to add a new alarm that was already associated with an EKAlarm")
        }
        let newBaseAlarm: EKAlarm?
        if let newTimeAlarm = newAlarm as? AbsoluteTimeAlarm {
            if !newTimeAlarm.isAllDay {
                newBaseAlarm = EKAlarm(absoluteDate: newTimeAlarm.time)
            } else {
                newBaseAlarm = nil
            }
        } else if let newTimeAlarm = newAlarm as? RelativeTimeAlarm {
            newBaseAlarm = EKAlarm(relativeOffset: newTimeAlarm.offset)
        } else if let newProxAlarm = newAlarm as? ProximityAlarm {
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
            throw BethinkMeError("unable to coerce plain BethinkeryAlarm to any known type when saving: \(newAlarm)")
        }

        do {
            newAlarm.baseAlarm = newBaseAlarm
            bethinkery.alarms.append(newAlarm)
            modelContext.insert(newAlarm)
            let reminder = try bethinkery.toReminder()
            if newBaseAlarm != nil {
                reminder.addAlarm(newBaseAlarm!)
            }
        } catch {
            throw BethinkMeError("failed to add alarm to Bethinkery", from: error as NSError)
        }
    }

    func removeAlarm(_ alarm: BethinkeryAlarm, from bethinkery: Bethinkery) throws {
        do {
            bethinkery.alarms.removeAll(where: { $0.id == alarm.id })
            modelContext.delete(alarm)

            let reminder = try bethinkery.toReminder()
            if alarm.baseAlarm != nil {
                reminder.removeAlarm(alarm.baseAlarm!)
            }
        } catch {
            throw BethinkMeError("failed to delete alarm", from: error as NSError)
        }
    }

    func replaceAlarms(on bethinkery: Bethinkery, with alarms: [BethinkeryAlarm]) throws {
        for oldAlarm in bethinkery.alarms {
            try removeAlarm(oldAlarm, from: bethinkery)
        }

        for newAlarm in alarms {
            try addAlarm(try newAlarm.cloneAsTemplate(), to: bethinkery)
        }
        do {
            try eventStore.save(bethinkery.toReminder(), commit: true)
        } catch {
            throw BethinkMeError("failed to save Bethinkery after replacing alarms", from: error as NSError)
        }
    }
}
