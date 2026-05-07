import EventKit


struct BethinkeryList: Identifiable {
    let id: String
    var title: String
    private let calendar: EKCalendar
    
    init(id: String, title: String, calendar: EKCalendar) {
        self.id = id
        self.title = title
        self.calendar = calendar
    }
    
    init(calendar: EKCalendar) {
        self.init(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            calendar: calendar)
    }
    
    func toCalendar() -> EKCalendar {
        calendar.title = title
        
        return calendar
    }
}

struct Bethinkery: Identifiable {
    let id: String
    let list: String
    var title: String
    var isCompleted: Bool
    private let reminder: EKReminder
    
    init(id: String, list: String, title: String, isCompleted: Bool, reminder: EKReminder) {
        self.id = id
        self.list = list
        self.title = title
        self.isCompleted = isCompleted
        self.reminder = reminder
    }
    
    init(reminder: EKReminder) {
        self.init(
            id: reminder.calendarItemIdentifier,
            list: reminder.calendar.calendarIdentifier,
            title: reminder.title,
            isCompleted: reminder.isCompleted,
            reminder: reminder)
    }
    
    func toReminder() -> EKReminder {
        reminder.title = title
        reminder.isCompleted = isCompleted
        
        return reminder
    }
}

@MainActor
@Observable class ViewModel {
    private let eventStore = EKEventStore()
    
    var hasAccess: Bool = false
    var bethinkeryLists: [BethinkeryList] = []
    var bethinkeries: [Bethinkery] = []
    var availableSources: [EKSource] = []
    var selectedCalendar: EKCalendar?
    
    func checkPermissions() async -> Bool {
        hasAccess = (try? await eventStore.requestFullAccessToReminders()) ?? false
        return hasAccess
    }
    
    func loadLists() async {
        guard await checkPermissions() else {
            print("tried to load lists without permissions!")
            return
        }
        
        bethinkeryLists.removeAll()
        bethinkeries.removeAll()
        
        let validSourceTypes = [EKSourceType.local, .exchange, .calDAV]
        let lists = eventStore
            .calendars(for: .reminder)
            .filter({ validSourceTypes.contains($0.source.sourceType )})
        
        for list in lists {
            let newList = BethinkeryList(calendar: list)
            bethinkeryLists.append(newList)
            
            let loadedReminders = await loadRemindersForList(list: list)
            for reminder in loadedReminders {
                let newReminder =  Bethinkery(reminder: reminder)
                bethinkeries.append(newReminder)
            }
            
        }
        availableSources = eventStore.sources
            .filter({ validSourceTypes.contains($0.sourceType )})
        selectedCalendar = eventStore.defaultCalendarForNewReminders() ?? lists.first
    }
    
    func create(title: String, list: BethinkeryList) {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = list.toCalendar()
        
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            print("failed to save new!")
        }
        
        let bethinkery = Bethinkery(reminder: reminder)
        self.bethinkeries.append(bethinkery)
    }
    
    func toggleComplete(for bethinkery: inout Bethinkery) {
        bethinkery.isCompleted.toggle()
        update(bethinkery: bethinkery)
    }
    
    func update(bethinkery: Bethinkery) {
        do {
            try eventStore.save(bethinkery.toReminder(), commit: true)
        } catch {
            print("failed to save toggle complete!")
        }
    }
    
    func delete(offsets: IndexSet){
        for idx in offsets {
            do {
                let bethinkery = bethinkeries.remove(at: idx)
                try eventStore.remove(bethinkery.toReminder(), commit: true)
            } catch {
                print("failed to delete!")
            }
        }
    }
    
    private func loadRemindersForList(list: EKCalendar) async -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: [list])
        
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
}
