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
}
