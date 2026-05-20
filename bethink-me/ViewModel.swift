import EventKit
import SwiftData
import SwiftUI


@MainActor
@Observable class ViewModel {
    private let modelContext: ModelContext
    private let eventStore = EKEventStore()
    
    var hasAccess: Bool = false
    var availableSources: [EKSource] = []
    var selectedCalendar: EKCalendar?
    
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
                return showCompleted || !bethinkery.isCompleted
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
    
    func loadLists() async {
        guard await checkPermissions() else {
            print("tried to load lists without permissions!")
            return
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
                currentList.update(from: ekcal)
            } else if existingLists.count == 0 {
                // | yes reminder, no storage
                // add it
                currentList = BethinkeryList(calendar: ekcal)
                modelContext.insert(currentList)
            } else {
                print("found multiple matching cal ids for \(ekcal.calendarIdentifier)!")
                continue
            }
            
            let loadedReminders = await loadRemindersForCalendar(calendar: ekcal)
            for ekrem in loadedReminders {
                let existingBethinkeries = currentList.bethinkeries.filter({ $0.id == ekrem.calendarItemIdentifier })

                if existingBethinkeries.count == 1 {
                    // = yes reminder, yes storage
                    // make sure fields are in sync
                    let existingBethinkery = existingBethinkeries.first!
                    existingBethinkery.update(from: ekrem)
                } else if existingBethinkeries.count == 0 {
                    // | yes reminder, no storage
                    // add it
                    let newReminder =  Bethinkery(reminder: ekrem, list: currentList)
                    currentList.bethinkeries.append(newReminder)
                    modelContext.insert(newReminder)
                } else {
                    print("found multiple matching rem ids for \(ekrem.calendarItemIdentifier)!")
                    continue
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
        selectedCalendar = eventStore.defaultCalendarForNewReminders() ?? calendars.first
    }
    
    func create(title: String, list: BethinkeryList) {
        do {
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = title
            reminder.calendar = try? list.toCalendar()
            
            try eventStore.save(reminder, commit: true)
            
            let newBethinkery = Bethinkery(reminder: reminder, list: list)
            
            modelContext.insert(newBethinkery)
            resetOrdinals()
        } catch {
            print("failed to save new!")
        }
    }
    
    func update(bethinkery: Bethinkery, title: String?, isCompleted: Bool?) {
        // theres gotta be a cleaner way
        if title != nil {
            bethinkery.title = title!
        }
        if isCompleted != nil {
            bethinkery.isCompleted = isCompleted!
        }
        
        do {
            try eventStore.save(bethinkery.toReminder(), commit: true)
        } catch {
            print("failed to save update!")
        }
    }

    func delete(bethinkeryList: BethinkeryList){
        do {
            try eventStore.removeCalendar(bethinkeryList.toCalendar(), commit: true)
            modelContext.delete(bethinkeryList)
        } catch {
            print("failed to delete list!")
        }
    }

    func delete(bethinkery: Bethinkery){
        do {
            try eventStore.remove(bethinkery.toReminder(), commit: true)
            modelContext.delete(bethinkery)
        } catch {
            print("failed to delete bethinkery!")
        }
    }
    
    func moveList(from: IndexSet, to: Int) {
        var tmpLists = bethinkeryLists
        tmpLists.move(fromOffsets: from, toOffset: to)
        
        for (idx, list) in tmpLists.enumerated() {
            list.ordinal = idx
        }
    }
    
    func moveBethinkery(from: IndexSet, to: Int, list: BethinkeryList) {
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
    
    func resetOrdinals() {
        for (idx, list) in bethinkeryLists.enumerated() {
            list.ordinal = idx
            
            for (idx, bethinkery) in unfilteredBethinkeries.enumerated()
                .filter({ $0.1.list.id == list.id }) {
                bethinkery.ordinal = idx
            }
        }
    }
    
    
    private func loadRemindersForCalendar(calendar: EKCalendar) async -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: [calendar])
        
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
}
