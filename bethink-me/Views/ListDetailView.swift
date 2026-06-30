import EventKit
import SwiftUI


struct ListDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true

    @Environment(\.dismiss)
    private var dismiss

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
                                alarmList: editListCommand.alarmTemplates,
                                scrollProxy: scrollProxy,
                                onAdd: { alarm in
                                    editListCommand.alarmTemplates.append(alarm)
                                },
                                onDelete: { alarm in
                                    editListCommand.alarmTemplates.removeAll(where: { $0.id == alarm.id })
                                }
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
                                        guard selectedSource != nil else {
                                            throw BethinkMeError("tried to create a List on a nonexistent Source")
                                        }
                                        try listModel.create(from: editListCommand, source: selectedSource!)
                                    } else {
                                        try listModel.update(list!, with: editListCommand)
                                    }
                                    dismiss()
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
        if list != nil {
            _editListCommand = StateObject(wrappedValue: .fromBethinkeryList(list!))
        }
    }
}
