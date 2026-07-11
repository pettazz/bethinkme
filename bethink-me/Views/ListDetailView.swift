import EventKit
import SwiftUI


struct ListDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true

    @Environment(\.dismiss)
    private var dismiss

    @State private var alertDialogModel: AlertDialogModel = AlertDialogModel()

    @StateObject private var editListCommand: EditBethinkeryList = EditBethinkeryList()

    @State private var newColor: Color = Color.accentColor
    @State private var newSourceId: String = ""

    var sharedModel: SharedViewModel
    var listModel: ListViewModel
    var list: BethinkeryList?


    private var isNew: Bool { list == nil }

    private var selectedSource: EKSource? {
        listModel.availableSources.first(where: { $0.sourceIdentifier == newSourceId })
    }

    var body: some View {
        if !listModel.availableSources.isEmpty {
            // TODO: make this less ugly, see also BethinkeryDetailView
            NavigationStack {
                VStack {
                    Text(editListCommand.title.isEmpty ? "New List" : editListCommand.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(newColor)
                        .font(.largeTitle)
                        .bold()
                        .padding(20)
                    ScrollViewReader { scrollProxy in
                        Form {
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

                            AlarmsEditView(
                                alarmList: $editListCommand.alarmTemplates,
                                scrollProxy: scrollProxy
                            )
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            withAnimation {
                                withErrorReporter {
                                    editListCommand.hexColor = newColor.toHex()
                                    if isNew {
                                        guard let selectedSource else {
                                            throw BethinkMeError("tried to create a List on a nonexistent Source")
                                        }
                                        try listModel.create(from: editListCommand, source: selectedSource)
                                        dismiss()
                                    } else {
                                        guard let list else {
                                            throw BethinkMeError("tried to update list that doesn't exist")
                                        }
                                        if !(list.liveBethinkeries.isEmpty) {
                                            displayAlarmEditAlertDialog(list: list, editListCommand: editListCommand)
                                        } else {
                                            try listModel.update(list, with: editListCommand)
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
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

    init(sharedModel: SharedViewModel, listModel: ListViewModel, list: BethinkeryList? = nil) {
        self.sharedModel = sharedModel
        self.listModel = listModel
        self.list = list
        if let list {
            _editListCommand = StateObject(wrappedValue: .fromBethinkeryList(list))
        }
    }

    private func displayAlarmEditAlertDialog(list: BethinkeryList, editListCommand: EditBethinkeryList) {
        alertDialogModel.title = "Editing List Alarms"
        // swiftlint:disable:next line_length
        alertDialogModel.message = "This list already contains Reminders. Do you want to discard any existing alarms they have set and replace them with the alarms from this list?"
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
        alertDialogModel.actions = actions
        alertDialogModel.showDefaultCancel = true
        alertDialogModel.isPresenting = true
    }
}
