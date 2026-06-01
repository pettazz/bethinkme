import EventKit
import SwiftData
import SwiftUI


@MainActor
@Observable class ViewModel {
    @ObservationIgnored
    @AppStorage(SettingsKey.maxCompletedAgeDays.rawValue)
    private var maxCompletedAgeDaysSetting: Int = 7
    
    private let modelContext: ModelContext
    private nonisolated final let eventStore = EKEventStore()
    
    var hasAccess: Bool = false
    var availableSources: [EKSource] = []
    var defaultSource: EKSource?
    
    var showCompleted: Bool = false
    
    init(modelContext: ModelContext) async {
        self.modelContext = modelContext
        self.hasAccess = await checkPermissions()
    }
    
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

    
    func checkPermissions() async -> Bool {
        hasAccess = (try? await eventStore.requestFullAccessToReminders()) ?? false
        return hasAccess
    }
    
    func loadLists() async throws {
//        try! await Task.sleep(for: .milliseconds(1500))
        guard await checkPermissions() else {
            throw BethinkMeError("tried to loadLists without permissions")
        }
        
        let validSourceTypes = [EKSourceType.local, .exchange, .calDAV]
        let calendars = eventStore
            .calendars(for: .reminder)
            .filter({ validSourceTypes.contains($0.source.sourceType) })
        
        // reconcile the stored data with Reminders
        // assume EK is always the real source of truth and update ours accordingly
        // three possibilities:
        // = yes reminder, yes storage
        // | yes reminder, no storage
        // X no reminder, yes storage
        
        for ekcal in calendars {
            let existingLists = bethinkeryLists.filter({ $0.id == ekcal.calendarIdentifier })
            let currentList: BethinkeryList
            
            if existingLists.count == 1 {
                // = yes reminder, yes storage
                // make sure fields are in sync
                currentList = existingLists.first!
                currentList.load(from: ekcal)
            } else if existingLists.count == 0 {
                // | yes reminder, no storage
                // add it
                currentList = BethinkeryList(calendar: ekcal)
                modelContext.insert(currentList)
            } else {
                throw BethinkMeError("found multiple matching cal ids for \(ekcal.calendarIdentifier)")
            }
            
            let loadedReminders = await loadRemindersForCalendar(ekcal)
            for ekrem in loadedReminders {
                let existingBethinkeries = currentList.bethinkeries.filter({ $0.id == ekrem.calendarItemIdentifier })

                if existingBethinkeries.count == 1 {
                    // = yes reminder, yes storage
                    // make sure fields are in sync
                    let existingBethinkery = existingBethinkeries.first!
                    existingBethinkery.load(from: ekrem)
                } else if existingBethinkeries.count == 0 {
                    // | yes reminder, no storage
                    // add it
                    let newReminder =  Bethinkery(reminder: ekrem, list: currentList)
                    currentList.bethinkeries.append(newReminder)
                    modelContext.insert(newReminder)
                } else {
                    throw BethinkMeError("found multiple matching rem ids for \(ekrem.calendarItemIdentifier)!")
                }
            }
            
            for danglingReminder in currentList.bethinkeries.filter({ savedBethinkery in
                // we never found an ekreminder to attach to this
                !savedBethinkery.hasReminder ||
                // the stored reminder's ekreminder no longer exists in the ekreminders for this list
                !loadedReminders.contains(where: { $0.calendarItemIdentifier == savedBethinkery.id })
            }) {
                // X no reminder, yes storage
                // remove it
                modelContext.delete(danglingReminder)
            }
        }
        
        for danglingList in bethinkeryLists.filter({ savedList in
            // we never found an ekcal to attach to this
            !savedList.hasCalendar ||
            // the stored list's ekcal no longer exists in the cals for this list
            !calendars.contains(where: { $0.calendarIdentifier == savedList.id })
        }) {
            // X no reminder, yes storage
            // remove it, also removes any reminders still attached to it
            modelContext.delete(danglingList)
        }
        
        // ensure we have ordinals set if we havent edited order before
        resetOrdinals()
        
        availableSources = eventStore.sources
            .filter({ validSourceTypes.contains($0.sourceType )})
        if !calendars.isEmpty {
            let defaultCal = eventStore.defaultCalendarForNewReminders() ?? calendars.first!
            defaultSource = defaultCal.source
        }
        
    }
    
    func createList(from createCommand: EditBethinkeryList, source: EKSource) {
        do {
            let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
            newCalendar.source = source
            newCalendar.title = createCommand.title
            newCalendar.cgColor = Color(hex: createCommand.hexColor).cgColor
            
            try eventStore.saveCalendar(newCalendar, commit: true)
            
            let newBethinkeryList = BethinkeryList(calendar: newCalendar)
            
            modelContext.insert(newBethinkeryList)
            resetOrdinals()
        } catch {
            print("failed to save new list!")
        }
    }
    
    func create(from createCommand: EditBethinkery, list: BethinkeryList) {
        do {
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = createCommand.title
            reminder.isCompleted = createCommand.isCompleted
            reminder.calendar = try list.toCalendar()
            
            try eventStore.save(reminder, commit: true)
            
            let newBethinkery = Bethinkery(reminder: reminder, list: list)
            
            modelContext.insert(newBethinkery)
            list.bethinkeries.insert(newBethinkery, at: 0)
            resetOrdinals()
        } catch {
            print("failed to save new!")
        }
    }
    
    func update(_ bethinkeryList: BethinkeryList, with updateCommand: EditBethinkeryList) {
        bethinkeryList.title = updateCommand.title
        bethinkeryList.hexColor = updateCommand.hexColor
        
        do {
            try eventStore.saveCalendar(bethinkeryList.toCalendar(), commit: true)
        } catch {
            print("failed to save list update!")
        }
    }
    
    func update(_ bethinkery: Bethinkery, with updateCommand: EditBethinkery) {
        bethinkery.title = updateCommand.title
        bethinkery.isCompleted = updateCommand.isCompleted
        bethinkery.freshlyCompleted = updateCommand.freshlyCompleted
        
        do {
            try eventStore.save(bethinkery.toReminder(), commit: true)
        } catch {
            print("failed to save update!")
        }
    }
    
    func toggleCompleted(_ bethinkery: Bethinkery) {
        var updatedBethinkery = EditBethinkery.fromBethinkery(bethinkery)
        updatedBethinkery.isCompleted.toggle()
        updatedBethinkery.freshlyCompleted = updatedBethinkery.isCompleted
        update(bethinkery, with: updatedBethinkery)
    }

    func delete(_ bethinkeryList: BethinkeryList){
        do {
            try eventStore.removeCalendar(bethinkeryList.toCalendar(), commit: true)
            modelContext.delete(bethinkeryList)
        } catch {
            print("failed to delete list!")
        }
    }

    func delete(_ bethinkery: Bethinkery){
        do {
            try eventStore.remove(bethinkery.toReminder(), commit: true)
            modelContext.delete(bethinkery)
        } catch {
            print("failed to delete bethinkery!")
        }
    }
    
    func moveListPosition(from: IndexSet, to: Int) {
        var tmpLists = bethinkeryLists
        tmpLists.move(fromOffsets: from, toOffset: to)
        
        for (idx, list) in tmpLists.enumerated() {
            list.ordinal = idx
        }
    }
    
    func moveBethinkeryPosition(from: IndexSet, to: Int, list: BethinkeryList) {
        guard from.count == 1 else {
            print("invalid number of items sent to move!")
            return
        }
        var tmpBethinkeries = bethinkeries.filter({ $0.list.id == list.id })
        tmpBethinkeries.move(fromOffsets: from, toOffset: to)
        
        // only reordinalize stuff in the affected range to limit weird moving of hidden items
        for (idx, bethinkery) in tmpBethinkeries[...(max(from.first!, to))].enumerated() {
            bethinkery.ordinal = idx
        }
    }
    
    func moveBethinkery(_ bethinkery: Bethinkery, to: BethinkeryList) {
        let currentList = bethinkery.list
        guard currentList != to else { return }
        
        // TODO: ensure we strip existing list-applied rules like location/time alerts, add new ones
        let clonedBethinkery = EditBethinkery.fromBethinkery(bethinkery)
        delete(bethinkery)
        create(from: clonedBethinkery, list: to)
    }
    
    func resetOrdinals() {
        for (idx, list) in bethinkeryLists.enumerated() {
            list.ordinal = idx
            
            for (idx, bethinkery) in unfilteredBethinkeries.enumerated()
                .filter({ $0.1.list.id == list.id }) {
                bethinkery.ordinal = idx
                bethinkery.freshlyCompleted = false // hehehehe side effects
            }
        }
    }
    
    
    private func loadRemindersForCalendar(_ calendar: EKCalendar) async -> [EKReminder] {
        var ageLimitDateComponents = DateComponents()
        ageLimitDateComponents.day = -1 * maxCompletedAgeDaysSetting
        let ageLimitDate = Calendar.current.date(byAdding: ageLimitDateComponents, to: Date.now, wrappingComponents: false)
        
        async let completeds = withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: eventStore.predicateForCompletedReminders(
                withCompletionDateStarting: ageLimitDate,
                ending: Date.now,
                calendars: [calendar])) { reminders in
                    continuation.resume(returning: reminders ?? [])
            }
        }
        async let incompleteds = withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: [calendar])) { reminders in
                    continuation.resume(returning: reminders ?? [])
            }
        }
        
        let (fetchedCompleteds, fetchedIncompleteds) = await (completeds, incompleteds)
        return fetchedCompleteds + fetchedIncompleteds
    }
}
