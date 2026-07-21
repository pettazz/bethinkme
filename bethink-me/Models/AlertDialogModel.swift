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

    func dismiss() {
        self.isPresenting = false
        self.title = ""
        self.message = ""
        self.actions = []
        self.showDefaultCancel = false
    }
}
