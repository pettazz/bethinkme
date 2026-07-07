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

    func refreshEK(for bethinkeries: [Bethinkery]) throws {
        for bethinkery in bethinkeries {
            guard let reminder = eventStore.calendarItem(withIdentifier: bethinkery.id) as? EKReminder else { continue }
            try bethinkery.load(from: reminder)
        }
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

    func addAlarm(_ template: any BethinkeryAlarmTemplate, to bethinkery: Bethinkery) throws {
        let newAlarm = template.toModel()
        let newBaseAlarm: EKAlarm?

        switch newAlarm.kind {
            case .absoluteTimeAlarm:
                if !newAlarm.isAllDay {
                    guard let alarmTime = newAlarm.time else {
                        throw BethinkMeError("tried to create absoluteTime BethinkeryAlarm from template missing time")
                    }
                    newBaseAlarm = EKAlarm(absoluteDate: alarmTime)
                } else {
                    newBaseAlarm = nil
                }
            case .relativeTimeAlarm:
                newBaseAlarm = EKAlarm(relativeOffset: newAlarm.offset)
            case .proximityAlarm:
                let location = EKStructuredLocation(title: newAlarm.title)
                location.geoLocation = CLLocation(latitude: newAlarm.location.lat, longitude: newAlarm.location.lng)
                location.radius = newAlarm.radius
                newBaseAlarm = EKAlarm(relativeOffset: 0)
                newBaseAlarm!.structuredLocation = location
                newBaseAlarm!.proximity = switch newAlarm.proximityType {
                    case .enter: .enter
                    case .leave: .leave
                    case .nothing: .none
                }
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

            if !(alarm.kind == .absoluteTimeAlarm && alarm.isAllDay) {
                let reminder = try bethinkery.toReminder()
                if let ekAlarm = alarm.baseAlarm ?? reminder.alarms?.first(where: { alarm == $0 }) {
                    reminder.removeAlarm(ekAlarm)
                }
            }
        } catch {
            throw BethinkMeError("failed to delete alarm", from: error as NSError)
        }
    }

    func replaceAlarms(on bethinkery: Bethinkery, with templates: [any BethinkeryAlarmTemplate]) throws {
        let oldAlarms = bethinkery.alarms

        for oldAlarm in oldAlarms {
            try removeAlarm(oldAlarm, from: bethinkery)
        }
        for newAlarm in templates {
            try addAlarm(newAlarm, to: bethinkery)
        }

        do {
            try eventStore.save(bethinkery.toReminder(), commit: true)
        } catch {
            throw BethinkMeError("failed to save Bethinkery after replacing alarms", from: error as NSError)
        }
    }
}
