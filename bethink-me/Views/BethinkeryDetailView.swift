import SwiftUI


struct BethinkeryDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = kEnableAutocorrectDefault

    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var editBethinkeryCommand: EditBethinkery = EditBethinkery()

    @State private var isPresentingEditAlarmsView: Bool = false

    var bethinkeryModel: BethinkeryViewModel
    var bethinkery: Bethinkery

    var body: some View {
        DetailEditor(title: editBethinkeryCommand.title,
                     color: Color(hex: bethinkery.list.hexColor),
                     onSave: save) {
            Section {
                TextField(
                    editBethinkeryCommand.title,
                    text: $editBethinkeryCommand.title,
                    prompt: Text("Title"))
                .autocorrectionDisabled(!enableAutocorrectSetting)

                TextField(
                    "Notes",
                    text: $editBethinkeryCommand.notesText,
                    prompt: Text("Notes"),
                    axis: .vertical)

                TextField(
                    "URL",
                    text: $editBethinkeryCommand.urlText,
                    prompt: Text("URL"))
                .keyboardType(.URL)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            }

            AlarmsListView(alarmList: $editBethinkeryCommand.alarms)
        } footer: {
            AddAlarmButton(color: Color(hex: bethinkery.list.hexColor)) {
                isPresentingEditAlarmsView = true
            }
        }
        .sheet(isPresented: $isPresentingEditAlarmsView) {
            AlarmsEditView(alarmList: $editBethinkeryCommand.alarms,
                           color: Color(hex: bethinkery.list.hexColor))
        }
    }

    init(bethinkeryModel: BethinkeryViewModel, bethinkery: Bethinkery) {
        self.bethinkeryModel = bethinkeryModel
        self.bethinkery = bethinkery
        _editBethinkeryCommand = StateObject(wrappedValue: .fromBethinkery(bethinkery))
    }

    private func save() {
        withErrorReporter {
            try bethinkeryModel.update(bethinkery, with: editBethinkeryCommand)
            dismiss()
        }
    }
}
