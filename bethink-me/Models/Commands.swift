import SwiftUI

// a set of intermediate not-objects to use for holding all the fields
// we want to do something with at once, rather than passing them around individually
// yeah we could just edit the model directly but I don't like the idea of either
// decoupling it from the backing object commit to EventKit or doing that in a view

@Observable
class EditBethinkeryList {
    var title: String
    var hexColor: String
    var alarmTemplates: [any BethinkeryAlarmTemplate] = []

    init(title: String = "",
         hexColor: String = "",
         alarmTemplates: [any BethinkeryAlarmTemplate] = []) {
        self.title = title
        self.hexColor = hexColor
        self.alarmTemplates = alarmTemplates
    }

    static func fromBethinkeryList(_ bethinkeryList: BethinkeryList) -> EditBethinkeryList {
        return EditBethinkeryList(
            title: bethinkeryList.title,
            hexColor: bethinkeryList.hexColor,
            alarmTemplates: bethinkeryList.alarmTemplates.compactMap({ $0.toTemplate() }))
    }
}

@Observable
class EditBethinkery {
    var title: String = ""
    var isCompleted: Bool = false
    var freshlyCompleted: Bool = false
    var notesText: String = ""
    var priority: Int = 0
    var alarms: [any BethinkeryAlarmTemplate] = []

    var notes: String? {
        notesText.isEmpty ? nil : notesText
    }

    init(title: String = "",
         isCompleted: Bool = false,
         freshlyCompleted: Bool = false,
         notesText: String = "",
         priority: Int = 0,
         alarms: [any BethinkeryAlarmTemplate] = []) {
        self.title = title
        self.isCompleted = isCompleted
        self.freshlyCompleted = freshlyCompleted
        self.notesText = notesText
        self.priority = priority
        self.alarms = alarms
    }

    static func fromBethinkery(_ bethinkery: Bethinkery) -> EditBethinkery {
        return EditBethinkery(
            title: bethinkery.title,
            isCompleted: bethinkery.isCompleted,
            freshlyCompleted: bethinkery.freshlyCompleted,
            notesText: bethinkery.notes ?? "",
            priority: bethinkery.priority,
            alarms: bethinkery.alarms.compactMap({ $0.toTemplate() }))
    }
}
