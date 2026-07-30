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
    var showDefaultCancel: Bool = false

    var currentAlarms: [BethinkeryAlarmTemplate]?
    var diffAlarms: [BethinkeryAlarmTemplate]?

    var reminderList: [Bethinkery]?

    var duplicateList: DuplicateGroup?

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
