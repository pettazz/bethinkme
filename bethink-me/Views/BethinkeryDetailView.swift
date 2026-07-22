import SwiftUI


struct BethinkeryDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true

    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var editBethinkeryCommand: EditBethinkery = EditBethinkery()

    @State private var isPresentingEditAlarmsView: Bool = false

    var bethinkeryModel: BethinkeryViewModel
    var bethinkery: Bethinkery

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(editBethinkeryCommand.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(Color(hex: bethinkery.list.hexColor))
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

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

                    AlarmsListView(alarmList: $editBethinkeryCommand.alarms)
                }
                .contentMargins(.top, 10, for: .scrollContent)

                Button {
                    isPresentingEditAlarmsView = true
                } label: {
                    Text("Add alarm")
                        .padding(5)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: bethinkery.list.hexColor))
                .padding(.vertical, 15)

            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        withErrorReporter {
                            try bethinkeryModel.update(bethinkery, with: editBethinkeryCommand)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditAlarmsView) {
                AlarmsEditView(alarmList: $editBethinkeryCommand.alarms, color: Color(hex: bethinkery.list.hexColor))
            }
        }
    }

    init(bethinkeryModel: BethinkeryViewModel, bethinkery: Bethinkery) {
        self.bethinkeryModel = bethinkeryModel
        self.bethinkery = bethinkery
        _editBethinkeryCommand = StateObject(wrappedValue: .fromBethinkery(bethinkery))
    }
}
