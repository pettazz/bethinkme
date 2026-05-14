import EventKit
import SwiftData
import SwiftUI


@Model
class BethinkeryList: Equatable, Hashable, Identifiable {
    var id: String
    var title: String
    var bethinkeries: [Bethinkery] = []
    var color: Color
    private var calendar: EKCalendar
    
    
    init(id: String, title: String, color: Color, calendar: EKCalendar) {
        self.id = id
        self.title = title
        self.color = color
        self.calendar = calendar
    }
    
    convenience init(calendar: EKCalendar) {
        self.init(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            color: Color(cgColor: calendar.cgColor),
            calendar: calendar)
    }
    
    static func == (lhs: BethinkeryList, rhs: BethinkeryList) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func toCalendar() -> EKCalendar {
        calendar.title = title
        calendar.cgColor = color.cgColor
        
        return calendar
    }
}

@Model
class Bethinkery: Equatable, Hashable, Identifiable {
    var id: String
    var list: String
    var title: String
    var isCompleted: Bool
    private var reminder: EKReminder
    
    
    init(id: String, list: String, title: String, isCompleted: Bool, reminder: EKReminder) {
        self.id = id
        self.list = list
        self.title = title
        self.isCompleted = isCompleted
        self.reminder = reminder
    }
    
    convenience init(reminder: EKReminder) {
        self.init(
            id: reminder.calendarItemIdentifier,
            list: reminder.calendar.calendarIdentifier,
            title: reminder.title,
            isCompleted: reminder.isCompleted,
            reminder: reminder)
    }
    
    static func == (lhs: Bethinkery, rhs: Bethinkery) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func toReminder() -> EKReminder {
        reminder.title = title
        reminder.isCompleted = isCompleted
        
        return reminder
    }
}
