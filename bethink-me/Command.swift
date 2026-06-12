import Foundation
import Combine

// a set of intermediate not-objects to use for holding all the fields
// we want to do something with at once, rather than passing them around individually
// yeah we could just edit the model directly but I don't like the idea of either
// decoupling it from the backing object commit to EventKit or doing that in a view

struct EditBethinkeryList {
    var title: String
    var hexColor: String

    static func fromBethinkeryList(_ bethinkeryList: BethinkeryList) -> EditBethinkeryList {
        return EditBethinkeryList(
            title: bethinkeryList.title,
            hexColor: bethinkeryList.hexColor)
    }
}

class EditBethinkery: ObservableObject {
    @Published var title: String = ""
    @Published var isCompleted: Bool = false
    @Published var freshlyCompleted: Bool = false
    @Published var notes: String?
    @Published var url: URL?
    @Published var dueDate: Date?

    init(title: String = "",
         isCompleted: Bool = false,
         freshlyCompleted: Bool = false,
         notes: String? = nil,
         url: URL? = nil,
         dueDate: Date? = nil) {
        self.title = title
        self.isCompleted = isCompleted
        self.freshlyCompleted = freshlyCompleted
        self.notes = notes
        self.url = url
        self.dueDate = dueDate
    }

    func loadFromBethinkery(_ bethinkery: Bethinkery) {
        self.title = bethinkery.title
        self.isCompleted = bethinkery.isCompleted
        self.freshlyCompleted = bethinkery.freshlyCompleted
        self.notes = bethinkery.notes
        self.url = bethinkery.url
        self.dueDate = bethinkery.dueDate
    }

    static func fromBethinkery(_ bethinkery: Bethinkery) -> EditBethinkery {
        return EditBethinkery(
            title: bethinkery.title,
            isCompleted: bethinkery.isCompleted,
            freshlyCompleted: bethinkery.freshlyCompleted,
            notes: bethinkery.notes,
            url: bethinkery.url,
            dueDate: bethinkery.dueDate)
    }
}
