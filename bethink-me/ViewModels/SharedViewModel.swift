import EventKit
import SwiftData


@MainActor
final class SharedViewModel {
    let modelContext: ModelContext
    nonisolated final let eventStore = EKEventStore()

    var hasAccess: Bool = false
    var showCompleted: Bool = false

    var bethinkeryLists: [BethinkeryList] {
        (try? modelContext.fetch(FetchDescriptor(
            sortBy: [.init(\BethinkeryList.ordinal)])))
        ?? []
    }

    var bethinkeries: [Bethinkery] {
        (try? modelContext.fetch(FetchDescriptor(
            predicate: #Predicate<Bethinkery> { bethinkery in
                return (showCompleted || !bethinkery.isCompleted) || bethinkery.freshlyCompleted
            },
            sortBy: [.init(\Bethinkery.ordinal)])))
        ?? []
    }

    var unfilteredBethinkeries: [Bethinkery] {
        (try? modelContext.fetch(FetchDescriptor(
            sortBy: [.init(\Bethinkery.ordinal)])))
        ?? []
    }


    init(modelContext: ModelContext) async {
        self.modelContext = modelContext
        self.hasAccess = await checkPermissions()
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
}
