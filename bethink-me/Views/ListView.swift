import SwiftUI


struct ListView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true

    @Environment(\.editMode)
    private var editMode

    @FocusState private var addInFocus: Bool
    @State private var isAdding: Bool = false
    @State private var newTitle: String = ""
    @State private var shouldPresentEditListSheet = false

    @Binding var selectedBethinkeryForEdit: Bethinkery?

    var model: ViewModel
    var list: BethinkeryList

    var body: some View {
        if editMode?.wrappedValue.isEditing == true {
            Text(list.title)
                .font(.headline)
                .foregroundColor(Color(hex: list.hexColor))
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

                let orderedBethinkeries = model.bethinkeries.filter({ $0.list.id == list.id })

                ForEach(orderedBethinkeries) { bethinkery in
                    RowView(model: model, bethinkery: bethinkery)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                withErrorReporter {
                                    try model.delete(bethinkery)
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
                                    ForEach(model.bethinkeryLists) { moveMenuList in
                                        if moveMenuList != list {
                                            Button {
                                                withAnimation {
                                                    withErrorReporter {
                                                        try model.moveBethinkery(bethinkery, to: moveMenuList)
                                                    }
                                                }
                                            } label: {
                                                HStack(spacing: 12) {
                                                    Image(systemName: "list.bullet.circle.fill")
                                                        .accessibilityHidden(true)
                                                        .foregroundStyle(
                                                                .white,
                                                                .secondary,
                                                                Color(hex: moveMenuList.hexColor))
                                                    Text(moveMenuList.title)
                                                }
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
                        try model.moveBethinkeryPosition(from: from, to: to, list: list)
                    }
                }
            }, header: {
                HStack {
                    Text(list.title)
                        .font(.headline)
                        .foregroundColor(Color(hex: list.hexColor))
                    Spacer()
                    Button {
                        shouldPresentEditListSheet.toggle()
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.title)
                            .foregroundColor(Color(hex: list.hexColor))
                            .accessibilityLabel(Text("Edit the \(list.title) list"))
                    }
                    .sheet(isPresented: $shouldPresentEditListSheet, content: {
                        ListDetailView(model: model, list: list)
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

    private func saveNew() {
        withErrorReporter {
            let cleanTitle = newTitle.trimmingCharacters(in: .whitespaces)
            guard !cleanTitle.isEmpty else { return }

            let newBethinkery = EditBethinkery(title: cleanTitle, isCompleted: false)
            try model.create(from: newBethinkery, list: list)
        }
        newTitle = ""
        addInFocus = true
    }

    private func closeAdding() {
        newTitle = ""
        isAdding = false
        addInFocus = false
    }
}
