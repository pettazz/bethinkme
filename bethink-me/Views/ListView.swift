import SwiftUI


struct ListView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true

    @Environment(\.editMode)
    private var editMode

    @Environment(AlertDialogModel.self)
    private var alertDialogModel

    @FocusState private var addInFocus: Bool
    @State private var isAdding: Bool = false
    @State private var newTitle: String = ""
    @State private var isPresentingEditListSheet: Bool = false

    @Binding var selectedBethinkeryForEdit: Bethinkery?

    var sharedModel: SharedViewModel
    var listModel: ListViewModel
    var bethinkeryModel: BethinkeryViewModel
    var list: BethinkeryList
    var onListDelete: (BethinkeryList) -> Void

    var body: some View {
        if editMode?.wrappedValue.isEditing == true {
            HStack {
                Button(role: .destructive) {
                    onListDelete(list)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .accessibilityLabel(Text("Delete List"))
                }
                Text(list.title)
                    .font(.headline)
                    .foregroundColor(Color(hex: list.hexColor))
                    .padding(.leading, 10)
            }
        } else {
            Section(content: {
                if isAdding {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .accessibilityHidden(true)
                        TextField("", text: $newTitle)
                            .autocorrectionDisabled(!enableAutocorrectSetting)
                            .textFieldStyle(.plain)
                            .focused($addInFocus)
                            .onAppear {
                                addInFocus = true
                            }
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") {
                                        closeAdding()
                                    }
                                }
                                ToolbarItem(placement: .keyboard) {
                                    Spacer()
                                }
                                ToolbarItem(placement: .keyboard) {
                                    Button("Done") {
                                        saveNew()
                                        closeAdding()
                                    }
                                }
                            }
                            .submitLabel(.next)
                            .onSubmit {
                                saveNew()
                            }
                    }
                }

                let orderedBethinkeries = sharedModel.bethinkeries.filter({ $0.list.id == list.id })

                ForEach(orderedBethinkeries) { bethinkery in
                    RowView(bethinkeryModel: bethinkeryModel, bethinkery: bethinkery)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                withErrorReporter {
                                    try bethinkeryModel.delete(bethinkery)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                selectedBethinkeryForEdit = bethinkery
                            } label: {
                                Label("Edit", systemImage: "square.and.pencil")
                            }
                            .tint(.orange)

                            Menu {
                                Section("Destination List") {
                                    ForEach(sharedModel.bethinkeryLists) { moveMenuList in
                                        if moveMenuList != list {
                                            Button {
                                                withErrorReporter {
                                                    try requestBethinkeryMove(bethinkery, destination: moveMenuList)
                                                }
                                            } label: {
                                                moveDestinationLabel(moveMenuList)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label("Move", systemImage: "arrow.left.arrow.right.square")
                            }
                        }
                }
                .onMove { from, to in
                    withErrorReporter {
                        try bethinkeryModel.moveBethinkeryPosition(from: from, to: to, list: list)
                    }
                }
            }, header: {
                HStack {
                    Text(list.title)
                        .font(.headline)
                        .foregroundColor(Color(hex: list.hexColor))
                    Spacer()
                    Button {
                        isPresentingEditListSheet.toggle()
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.title)
                            .foregroundColor(Color(hex: list.hexColor))
                            .accessibilityLabel(Text("Edit the \(list.title) list"))
                    }
                    .sheet(isPresented: $isPresentingEditListSheet, content: {
                        ListDetailView(sharedModel: sharedModel, listModel: listModel, list: list)
                            .textCase(.none)
                    })
                    Button {
                        withAnimation {
                            isAdding = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(Color(hex: list.hexColor))
                            .accessibilityLabel(Text("Add a new Bethinkery to the \(list.title) list"))
                    }
                }
            })
            .onChange(of: addInFocus) {
                if !addInFocus && isAdding {
                    closeAdding()
                }
            }
        }
    }

    @ViewBuilder
    private func moveDestinationLabel(_ destination: BethinkeryList) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.circle.fill")
                .accessibilityHidden(true)
                .foregroundStyle(.white, .secondary, Color(hex: destination.hexColor))
            Text(destination.title)
        }
    }

    private func saveNew() {
        withErrorReporter {
            let cleanTitle = newTitle.trimmingCharacters(in: .whitespaces)
            guard !cleanTitle.isEmpty else { return }

            let newBethinkery = EditBethinkery(title: cleanTitle, isCompleted: false)
            try bethinkeryModel.create(from: newBethinkery, list: list)
        }
        newTitle = ""
        addInFocus = true
    }

    private func closeAdding() {
        newTitle = ""
        isAdding = false
        addInFocus = false
    }

    private func doBethinkeryMove(_ bethinkery: Bethinkery,
                                  destination: BethinkeryList,
                                  inheritListAlarms: Bool) throws {
        try bethinkeryModel.moveBethinkery(bethinkery,
                                           to: destination,
                                           inheritListAlarms: inheritListAlarms)
    }

    private func requestBethinkeryMove(_ bethinkery: Bethinkery, destination: BethinkeryList) throws {
        if bethinkery.hasAlarms {
            if destination.hasAlarms {
                alertDialogModel.title = "Moving Reminder"
                // swiftlint:disable:next line_length
                alertDialogModel.message = "This Reminder has alarms and is being moved to a List with different alarms. Do you want to discard the existing alarms and replace them with the alarms from the new list?"
                let actions = [
                    ActionButton(title: "Replace with List alarms", role: .destructive, action: {
                        withErrorReporter {
                            try doBethinkeryMove(bethinkery, destination: destination, inheritListAlarms: true)
                        }
                    }),
                    ActionButton(title: "Keep existing alarms", action: {
                        withErrorReporter {
                            try doBethinkeryMove(bethinkery, destination: destination, inheritListAlarms: false)
                        }
                    })
                ]
                alertDialogModel.actions = actions
                alertDialogModel.currentAlarms = bethinkery.alarms.compactMap({ $0.toTemplate() })
                alertDialogModel.diffAlarms = destination.alarmTemplates.compactMap({ $0.toTemplate() })
                alertDialogModel.showDefaultCancel = true
                alertDialogModel.isPresenting = true
            } else {
                // retain existing alarms and don't inherit []
                try doBethinkeryMove(bethinkery, destination: destination, inheritListAlarms: false)
            }
        } else {
            try doBethinkeryMove(bethinkery, destination: destination, inheritListAlarms: true)
        }
    }
}
