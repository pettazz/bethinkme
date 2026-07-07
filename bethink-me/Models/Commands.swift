import Combine
import SwiftUI

// a set of intermediate not-objects to use for holding all the fields
// we want to do something with at once, rather than passing them around individually
// yeah we could just edit the model directly but I don't like the idea of either
// decoupling it from the backing object commit to EventKit or doing that in a view

class EditBethinkeryList: ObservableObject {
    @Published var title: String
    @Published var hexColor: String
    @Published var alarmTemplates: [any BethinkeryAlarmTemplate] = []

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

class EditBethinkery: ObservableObject {
    @Published var title: String = ""
    @Published var isCompleted: Bool = false
    @Published var freshlyCompleted: Bool = false
    @Published var notesText: String = ""
    @Published var urlText: String = ""
    @Published var alarms: [any BethinkeryAlarmTemplate] = []

    var notes: String? {
        notesText.isEmpty ? nil : notesText
    }

    var url: URL? {
        urlText.isEmpty ? nil : URL(string: urlText)
    }

    init(title: String = "",
         isCompleted: Bool = false,
         freshlyCompleted: Bool = false,
         notesText: String = "",
         urlText: String = "",
         alarms: [any BethinkeryAlarmTemplate] = []) {
        self.title = title
        self.isCompleted = isCompleted
        self.freshlyCompleted = freshlyCompleted
        self.notesText = notesText
        self.urlText = urlText
        self.alarms = alarms
    }

    static func fromBethinkery(_ bethinkery: Bethinkery) -> EditBethinkery {
        return EditBethinkery(
            title: bethinkery.title,
            isCompleted: bethinkery.isCompleted,
            freshlyCompleted: bethinkery.freshlyCompleted,
            notesText: bethinkery.notes ?? "",
            urlText: bethinkery.url?.absoluteString ?? "",
            alarms: bethinkery.alarms.compactMap({ $0.toTemplate() }))
    }
}
