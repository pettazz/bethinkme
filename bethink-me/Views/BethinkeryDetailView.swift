import SwiftUI


struct BethinkeryDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = kEnableAutocorrectDefault

    @Environment(\.dismiss)
    private var dismiss

    @State private var editBethinkeryCommand: EditBethinkery = EditBethinkery()

    @State private var isPresentingEditAlarmsView: Bool = false

    var bethinkeryModel: BethinkeryViewModel
    var bethinkery: Bethinkery

    var body: some View {
        @Bindable var editBethinkeryCommand = editBethinkeryCommand

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
            }

            Section {
//                Slider(value: Binding(
//                           get: { Double(editBethinkeryCommand.priority) },
//                           set: { editBethinkeryCommand.priority = Int($0) }
//                       ),
//                       in: 0...9,
//                       step: 1)
                let priority = BethinkeryPriority(rawValue: editBethinkeryCommand.priority) ?? .unset
                HStack {
                    if let icon = priority.shortRangeIcon {
                        Image(systemName: icon)
                            .font(.footnote)
                            .bold()
                            .foregroundColor(Color(hex: bethinkery.list.hexColor))
                            .accessibilityLabel(Text("\(priority.shortRangeTitle) priority"))
                    }
                    Picker("", selection: Binding(
                        get: { (BethinkeryPriority(rawValue: editBethinkeryCommand.priority) ?? .unset).shortened },
                        set: { editBethinkeryCommand.priority = $0 }
                    )) {
                        ForEach(BethinkeryPriority.shortRangeCases, id: \.self) { option in
                            Text(option.shortRangeTitle).tag(option.rawValue)
                        }
                    }
                }
            } header: {
                Text("Priority")
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
        _editBethinkeryCommand = State(wrappedValue: .fromBethinkery(bethinkery))
    }

    private func save() {
        withErrorReporter {
            try bethinkeryModel.update(bethinkery, with: editBethinkeryCommand)
            dismiss()
        }
    }
}
