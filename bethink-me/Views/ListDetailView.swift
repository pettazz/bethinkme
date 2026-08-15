import EventKit
import SwiftUI


struct ListDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = kEnableAutocorrectDefault

    @Environment(\.dismiss)
    private var dismiss

    @State private var alertDialogModel: AlertDialogModel = AlertDialogModel()

    @State private var editListCommand: EditBethinkeryList = EditBethinkeryList()

    @State private var newColor: Color = Color.accentColor
    @State private var newSourceId: String = ""

    @State private var isPresentingEditAlarmsView: Bool = false

    var sharedModel: SharedViewModel
    var listModel: ListViewModel
    var list: BethinkeryList?

    var onListCreated: ((String) -> Void)?


    private var isNew: Bool { list == nil }

    private var selectedSource: EKSource? {
        if !newSourceId.isEmpty {
            return listModel.availableSources.first(where: { $0.sourceIdentifier == newSourceId })
        } else if let list {
            return listModel.availableSources.first(where: { $0.sourceIdentifier == list.sourceId })
        } else {
            return nil
        }
    }

    var body: some View {
        @Bindable var editListCommand = editListCommand

        if !listModel.availableSources.isEmpty {
            DetailEditor(title: editListCommand.title.isEmpty ? "New List" : editListCommand.title,
                         subTitle: selectedSource?.title ?? nil,
                         color: newColor,
                         onSave: save) {
                Section {
                    TextField(editListCommand.title.isEmpty ? "New List" : editListCommand.title,
                              text: $editListCommand.title)
                    .autocorrectionDisabled(!enableAutocorrectSetting)

                    ColorPicker("List color", selection: $newColor)

                    if isNew {
                        Picker("Save to", selection: $newSourceId) {
                            ForEach(listModel.availableSources, id: \.sourceIdentifier) { source in
                                Text(source.title).tag(source.sourceIdentifier)
                            }
                        }
                    }
                }
                AlarmsListView(alarmList: $editListCommand.alarmTemplates)
            } footer: {
                AddAlarmButton(color: newColor) {
                    isPresentingEditAlarmsView = true
                }
            }
            .sheet(isPresented: $isPresentingEditAlarmsView) {
                AlarmsEditView(alarmList: $editListCommand.alarmTemplates, color: newColor)
            }
            .task {
                if isNew {
                    newSourceId = listModel.defaultSource?.sourceIdentifier ??
                    listModel.availableSources.first?.sourceIdentifier ?? ""
                } else {
                    newColor = Color(hex: editListCommand.hexColor)
                }
            }
            .alertDialogPresentable(alertModel: $alertDialogModel)
        } else {
            NavigationStack {
                InvalidStateView(icon: "arrow.down.app.dashed.trianglebadge.exclamationmark",
                                 title: "No Sources",
                                 message: "You have nowhere to save Reminders!",
                                 linkTitle: "Add an account in Settings!")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    init(sharedModel: SharedViewModel,
         listModel: ListViewModel,
         list: BethinkeryList? = nil,
         onListCreated: ((String) -> Void)? = nil) {
        self.sharedModel = sharedModel
        self.listModel = listModel
        self.list = list
        self.onListCreated = onListCreated
        if let list {
            _editListCommand = State(wrappedValue: .fromBethinkeryList(list))
        } else {
            _editListCommand = State(wrappedValue: EditBethinkeryList())
        }
    }

    private func displayAlarmEditAlertDialog(list: BethinkeryList, editListCommand: EditBethinkeryList) {
        let actions = [
            ActionButton(title: "Replace with List alarms", role: .destructive, action: {
                withErrorReporter {
                    try listModel.update(list, with: editListCommand, replaceBethinkeryAlarms: true)
                    dismiss()
                }
            }),
            ActionButton(title: "Keep existing alarms", action: {
                withErrorReporter {
                    try listModel.update(list, with: editListCommand)
                    dismiss()
                }
            })
        ]
        alertDialogModel.present(title: "Editing List Alarms",
                                 // swiftlint:disable:next line_length
                                 message: "This list already contains Reminders. Do you want to discard any existing alarms they have set and replace them with the alarms from this list?",
                                 actions: actions,
                                 diffAlarms: editListCommand.alarmTemplates)
    }

    private func save() {
        withErrorReporter {
            editListCommand.hexColor = newColor.toHex()
            if isNew {
                guard let selectedSource else {
                    throw BethinkMeError("tried to create a List on a nonexistent Source")
                }
                let newList = try listModel.create(from: editListCommand, source: selectedSource)
                onListCreated?(newList.id)
                dismiss()
            } else {
                guard let list else {
                    throw BethinkMeError("tried to update list that doesn't exist")
                }
                let alarmsChanged = Set(list.alarmTemplates.map(\.id)) != Set(editListCommand.alarmTemplates.map(\.id))
                if !(list.liveOrderedBethinkeries.isEmpty) && alarmsChanged {
                    displayAlarmEditAlertDialog(list: list, editListCommand: editListCommand)
                } else {
                    try listModel.update(list, with: editListCommand)
                    dismiss()
                }
            }
        }
    }
}
