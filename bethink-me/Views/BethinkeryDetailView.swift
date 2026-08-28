import SwiftUI


struct BethinkeryDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = kEnableAutocorrectDefault
    @AppStorage(SettingsKey.enableFullRangePriority.rawValue)
    private var enableFullRangePriority: Bool = kEnableFullRangePriorityDefault

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
                let priority = BethinkeryPriority(rawValue: editBethinkeryCommand.priority) ?? .unset

                Toggle("Set priority", isOn: Binding(
                    get: { editBethinkeryCommand.priority > 0 },
                    set: { editBethinkeryCommand.priority = $0 ? 5 : 0 }
                ))

                if editBethinkeryCommand.priority > 0 {
                    if enableFullRangePriority {
                        HStack {
                            Image(systemName: priority.icon ?? "lane")
                                .font(.title)
                                .bold()
                                .foregroundColor(Color(hex: bethinkery.list.hexColor))
                                .accessibilityLabel(Text("\(priority.title) priority"))
                            Slider(value: Binding(
                                // subtract from 10 so we invert, left is lowest right is highest
                                get: { 10 - Double(editBethinkeryCommand.priority) },
                                set: { editBethinkeryCommand.priority = 10 - Int($0) }
                            ),
                                   in: 1...9,
                                   step: 1)
                        }
                        Text(priority.title)
                    } else {
                        Picker("", selection: Binding(
                            get: { (BethinkeryPriority(rawValue: editBethinkeryCommand.priority) ?? .unset).shortened },
                            set: { editBethinkeryCommand.priority = $0 }
                        )) {
                            ForEach(BethinkeryPriority.shortRangeCases, id: \.self) { option in
                                Text(option.shortRangeTitle).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
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
