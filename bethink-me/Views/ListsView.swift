import SwiftUI


struct ListsView: View {
    var sharedModel: SharedViewModel
    var listModel: ListViewModel
    var bethinkeryModel: BethinkeryViewModel

    var isLoadingAny: Bool

    @Binding var selectedBethinkeryForEdit: Bethinkery?

    @Environment(AlertDialogModel.self)
    private var alertDialogModel

    @State private var listEditMode: EditMode = .inactive
    @State private var shouldPresentNewListSheet = false
    @State private var createdListID: String?

    @State private var addingToListID: String?

    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        if sharedModel.bethinkeryLists.isEmpty {
            InvalidStateView(icon: "checklist",
                             title: "oh no",
                             message: "no toedoes?")
        } else {
            Group {
                ScrollViewReader { scrollProxy in
                    List {
                        Section {
                            Color.clear
                                .frame(height: 0)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .id("lists-top")
                        }
                        .listSectionSpacing(0)

                        ForEach(sharedModel.bethinkeryLists) { list in
                            BethinkeryListSectionView(
                                selectedBethinkeryForEdit: $selectedBethinkeryForEdit,
                                addingToListID: $addingToListID,
                                sharedModel: sharedModel,
                                listModel: listModel,
                                bethinkeryModel: bethinkeryModel,
                                list: list,
                                scrollProxy: scrollProxy,
                                onListDelete: { list in
                                    displayListDeleteConfirmation(selectedListForDelete: list)
                                })
                        }
                        .onMove { from, to in
                            withErrorReporter {
                                try listModel.moveListPosition(from: from, to: to)
                            }
                        }
                    }
                    .environment(\.defaultMinListRowHeight, 0)
                    .environment(\.editMode, $listEditMode)
                    .contentMargins(.bottom, keyboardHeight, for: .scrollContent)
                    .onReceive(NotificationCenter.default.publisher(
                        for: UIResponder.keyboardWillShowNotification)) { note in
                            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                                as? CGRect {
                                keyboardHeight = frame.height
                            }
                    }
                    .onReceive(NotificationCenter.default.publisher(
                        for: UIResponder.keyboardWillHideNotification)) { _ in
                            keyboardHeight = 0
                    }
                    .sheet(
                        isPresented: $shouldPresentNewListSheet,
                        onDismiss: {
                            guard createdListID != nil else { return }
                            Task { @MainActor in
                                await Task.yield()
                                withAnimation {
                                    scrollProxy.scrollTo("lists-top", anchor: .top)
                                }
                                self.createdListID = nil
                            }
                        },
                        content: {
                            ListDetailView(sharedModel: sharedModel,
                                           listModel: listModel,
                                           onListCreated: { createdListID = $0 })
                            .textCase(.none)
                        }
                    )
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                if listEditMode != .active {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            shouldPresentNewListSheet = true
                        } label: {
                            Image(systemName: "rectangle.stack.fill.badge.plus")
                                .accessibilityLabel(Text("Add a new list"))
                        }
                        .disabled(isLoadingAny)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation {
                            listEditMode = listEditMode.isEditing ? .inactive : .active
                        }
                    } label: {
                        Image(systemName: listEditMode == .active
                              ? "checkmark.circle.fill"
                              : "arrow.up.arrow.down.square.fill")
                        .accessibilityLabel(Text(listEditMode == .active
                                                 ? "Done editing lists"
                                                 : "Edit lists"))
                    }
                    .disabled(isLoadingAny)
                }
                if listEditMode != .active {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation {
                                sharedModel.showCompleted.toggle()
                                sharedModel.reload()
                                sharedModel.resetOrdinals()
                            }
                        } label: {
                            if sharedModel.showCompleted {
                                Image(systemName: "eye.slash.fill")
                                    .accessibilityLabel(Text("Hide completed Bethinkeries"))
                            } else {
                                Image(systemName: "eye.fill")
                                    .accessibilityLabel(Text("Show completed Bethinkeries"))
                            }
                        }
                        .disabled(isLoadingAny)
                    }
                }
            }
        }
    }

    private func displayListDeleteConfirmation(selectedListForDelete: BethinkeryList) {
        var message = "This will permanently delete the list\n\n**\(selectedListForDelete.title)**\n\n"
        if !selectedListForDelete.bethinkeries.isEmpty {
            if selectedListForDelete.bethinkeries.count == 1 {
                message += "and its **Reminder.** "
            } else {
                message += "and all of its **\(selectedListForDelete.bethinkeries.count) Reminders.** "
            }
        }
        message += "This cannot be undone."
        let actions = [
            ActionButton(title: "Delete List", role: .destructive, action: {
                withErrorReporter {
                    try listModel.delete(selectedListForDelete)
                }
            })
        ]
        alertDialogModel.present(title: "Delete List",
                                 message: message,
                                 actions: actions,
                                 reminderList: selectedListForDelete.bethinkeries)
    }
}
