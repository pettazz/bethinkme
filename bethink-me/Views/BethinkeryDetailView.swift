import SwiftUI


struct BethinkeryDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true

    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var editBethinkeryCommand: EditBethinkery = EditBethinkery()

    var bethinkeryModel: BethinkeryViewModel
    var bethinkery: Bethinkery

    var body: some View {
        NavigationStack {
            VStack {
                // TODO: make this less ugly, see also BethinkeryListDetailView
                Text(editBethinkeryCommand.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(Color(hex: bethinkery.list.hexColor))
                    .font(.largeTitle)
                    .bold()
                    .padding(20)
                ScrollViewReader { scrollProxy in
                    Form {
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

                        AlarmsEditView(
                            alarmList: $editBethinkeryCommand.alarms,
                            scrollProxy: scrollProxy
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        withErrorReporter {
                            try bethinkeryModel.update(bethinkery, with: editBethinkeryCommand)
                            dismiss()
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
    }

    init(bethinkeryModel: BethinkeryViewModel, bethinkery: Bethinkery) {
        self.bethinkeryModel = bethinkeryModel
        self.bethinkery = bethinkery
        _editBethinkeryCommand = StateObject(wrappedValue: .fromBethinkery(bethinkery))
    }
}
