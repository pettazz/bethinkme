import EventKit


@MainActor
@Observable class ViewModel {
    private let eventStore = EKEventStore()
    
    var hasAccess: Bool = false
    var bethinkeryLists: [BethinkeryList] = []
    var availableSources: [EKSource] = []
    var selectedCalendar: EKCalendar?
    
    func checkPermissions() async -> Bool {
        hasAccess = (try? await eventStore.requestFullAccessToReminders()) ?? false
        return hasAccess
    }
    
    func loadLists(includeCompleted: Bool = true) async {
        guard await checkPermissions() else {
            print("tried to load lists without permissions!")
            return
        }
        
        bethinkeryLists.removeAll()
        
        let validSourceTypes = [EKSourceType.local, .exchange, .calDAV]
        let lists = eventStore
            .calendars(for: .reminder)
            .filter({ validSourceTypes.contains($0.source.sourceType) })
        
        for list in lists {
            let newList = BethinkeryList(calendar: list)
            
            let loadedReminders = await loadRemindersForCalendar(calendar: list)
            for reminder in loadedReminders {
                
                // TODO: pass and use a filter set instead of bool param. I mean maybe not are there other filters even?
                if !includeCompleted {
                    if reminder.isCompleted {
                        continue
                    }
                }
                
                let newReminder =  Bethinkery(reminder: reminder)
                newList.bethinkeries.append(newReminder)
            }
            bethinkeryLists.append(newList)
            
        }
        availableSources = eventStore.sources
            .filter({ validSourceTypes.contains($0.sourceType )})
        selectedCalendar = eventStore.defaultCalendarForNewReminders() ?? lists.first
    }
    
    func create(title: String, listId: String) {
        let list = getListById(id: listId)
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = list.toCalendar()
        
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            print("failed to save new!")
        }
        
        let newBethinkery = Bethinkery(reminder: reminder)
        list.bethinkeries.insert(newBethinkery, at: 0)
    }
    
    func update(bethinkery: Bethinkery) {
        do {
            try eventStore.save(bethinkery.toReminder(), commit: true)
        } catch {
            print("failed to save toggle complete!")
        }
    }

    func delete(offsets: IndexSet, from listId: String){
        guard offsets.count == 1 else {
            print("invalid number of offsets sent to delete!")
            return
        }
        let idx: Int = offsets.first!
        
        let list = getListById(id: listId)
        let bethinkery = list.bethinkeries.remove(at: idx)
        do {
            try eventStore.remove(bethinkery.toReminder(), commit: true)
        } catch {
            print("failed to delete!")
        }
        
    }
    
    private func getListById(id: String) -> BethinkeryList {
        guard let list = bethinkeryLists.first(where: { $0.id == id }) else {
            // TODO: real error handling
            print("bad list id!")
            fatalError()
        }
        return list
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
