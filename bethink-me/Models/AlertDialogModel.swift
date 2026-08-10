import SwiftUI


struct ActionButton {
    var title: String
    var role: ButtonRole?
    var action: () -> Void
}

@Observable
class AlertDialogModel {
    var isPresenting: Bool = false

    var title: String = ""
    var message: String = ""
    var actions: [ActionButton] = []
    var showDefaultCancel: Bool = true

    var currentAlarms: [BethinkeryAlarmTemplate]?
    var diffAlarms: [BethinkeryAlarmTemplate]?

    var reminderList: [Bethinkery]?

    var duplicateList: DuplicateGroup?

    func present(title: String,
                 message: String,
                 actions: [ActionButton],
                 currentAlarms: [BethinkeryAlarmTemplate]? = nil,
                 diffAlarms: [BethinkeryAlarmTemplate]? = nil,
                 reminderList: [Bethinkery]? = nil,
                 duplicateList: DuplicateGroup? = nil,
                 showDefaultCancel: Bool = true) {
        self.isPresenting = true
        self.title = title
        self.message = message
        self.actions = actions
        self.currentAlarms = currentAlarms
        self.diffAlarms = diffAlarms
        self.reminderList = reminderList
        self.duplicateList = duplicateList
        self.showDefaultCancel = showDefaultCancel
    }

    func dismiss() {
        self.isPresenting = false
        self.title = ""
        self.message = ""
        self.actions = []
        self.currentAlarms = nil
        self.diffAlarms = nil
        self.reminderList = nil
        self.duplicateList = nil
        self.showDefaultCancel = false
    }
}
