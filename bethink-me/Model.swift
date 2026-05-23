import EventKit
import SwiftData
import SwiftUI


@Model
final class BethinkeryList: Equatable, Identifiable {
    @Attribute(.unique)
    var id: String
    @Relationship(deleteRule: .cascade, inverse: \Bethinkery.list)
    var bethinkeries: [Bethinkery] = []
    var ordinal: Int = -1
    var title: String
    var hexColor: String
    @Transient
    private var calendar: EKCalendar?
    
    var hasCalendar: Bool {
        return self.calendar != nil
    }
    
    
    init(id: String, title: String, hexColor: String, calendar: EKCalendar) {
        self.id = id
        self.title = title
        self.hexColor = hexColor
        self.calendar = calendar
    }
    
    convenience init(calendar: EKCalendar) {
        self.init(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            hexColor: Color(cgColor: calendar.cgColor).toHex(),
            calendar: calendar)
    }
    
    
    static func == (lhs: BethinkeryList, rhs: BethinkeryList) -> Bool {
        return lhs.id == rhs.id
    }
    
    func load(from calendar: EKCalendar) {
        self.id = calendar.calendarIdentifier
        self.title = calendar.title
        self.hexColor = Color(cgColor: calendar.cgColor).toHex()
        self.calendar = calendar
    }
    
    func toCalendar() throws -> EKCalendar {
        guard self.hasCalendar else { throw RuntimeError(message: "calendar access before set") }
        self.calendar!.title = title
        // yes we are constantly going back and forth between Color and cgColor and String,
        // but SwiftData doesn't want to save Color/UIColor so okay whatever man 
        self.calendar!.cgColor = Color(hex: hexColor).cgColor
        
        return self.calendar!
    }
}

@Model
final class Bethinkery: Equatable, Identifiable {
    @Attribute(.unique)
    var id: String
    var list: BethinkeryList
    var ordinal: Int = -1
    var title: String
    var isCompleted: Bool
    @Transient
    var reminder: EKReminder?
    
    var hasReminder: Bool {
        return self.reminder != nil
    }
    
    
    init(id: String, list: BethinkeryList, title: String, isCompleted: Bool, reminder: EKReminder) {
        self.id = id
        self.list = list
        self.title = title
        self.isCompleted = isCompleted
        self.reminder = reminder
    }
    
    convenience init(reminder: EKReminder, list: BethinkeryList) {
        self.init(
            id: reminder.calendarItemIdentifier,
            list: list,
            title: reminder.title,
            isCompleted: reminder.isCompleted,
            reminder: reminder)
    }
    
    
    static func == (lhs: Bethinkery, rhs: Bethinkery) -> Bool {
        return lhs.id == rhs.id && lhs.list == rhs.list
    }
    
    func load(from reminder: EKReminder) {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title
        self.isCompleted = reminder.isCompleted
        self.reminder = reminder
    }
    
    func toReminder() throws -> EKReminder {
        guard self.hasReminder else { throw RuntimeError(message: "reminder access before set") }
        self.reminder!.title = title
        self.reminder!.isCompleted = isCompleted
        
        return self.reminder!
    }
}
