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
    @Relationship(deleteRule: .cascade)
    var alarmTemplates: [BethinkeryAlarm] = []
    var sourceId: String = ""

    var hasAlarms: Bool { return !self.alarmTemplates.isEmpty }

    var liveBethinkeries: [Bethinkery] {
        bethinkeries.filter({ !$0.isCompleted })
    }


    init(id: String, title: String, hexColor: String, calendar: EKCalendar) {
        self.id = id
        self.title = title
        self.hexColor = hexColor
        self.sourceId = calendar.source.sourceIdentifier
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
        self.sourceId = calendar.source.sourceIdentifier
    }

    func apply(to calendar: EKCalendar) {
        calendar.title = self.title
        // yes we are constantly going back and forth between Color and cgColor and String,
        // but SwiftData doesn't want to save Color/UIColor so okay whatever man
        calendar.cgColor = Color(hex: self.hexColor).cgColor
    }
}
