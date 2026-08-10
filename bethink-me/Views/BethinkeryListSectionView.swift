import SwiftUI


enum RowFlashKind: Equatable {
    case created
    case deduped
}

struct BethinkeryListSectionView: View {
    @Environment(\.editMode)
    private var editMode

    @Environment(AlertDialogModel.self)
    private var alertDialogModel

    @State private var flashedRow: (id: String, kind: RowFlashKind)?
    @State private var flashTrigger = 0

    @State private var isPresentingEditListSheet: Bool = false

    @Binding var selectedBethinkeryForEdit: Bethinkery?

    @Binding var addingToListID: String?

    var sharedModel: SharedViewModel
    var listModel: ListViewModel
    var bethinkeryModel: BethinkeryViewModel
    var list: BethinkeryList
    var scrollProxy: ScrollViewProxy?
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
                .buttonStyle(.borderless)
                .fixedSize()

                Text(list.title)
                    .font(.headline)
                    .foregroundColor(Color(hex: list.hexColor))
                    .padding(.leading, 10)
            }
        } else {
            Section(
                content: {
                    if addingToListID == list.id {
                        AddBethinkeryRowView(
                            list: list,
                            sharedModel: sharedModel,
                            bethinkeryModel: bethinkeryModel,
                            scrollProxy: scrollProxy,
                            addingToListID: $addingToListID,
                            onFlash: flash)
                    }

                    ForEach(list.visibleBethinkeries(showCompleted: sharedModel.showCompleted)) { bethinkery in
                        let flashKind = flashedRow.flatMap { $0.id == bethinkery.id ? $0.kind : nil }
                        RowView(bethinkeryModel: bethinkeryModel, bethinkery: bethinkery)
                            .id(bethinkery.id)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: list.hexColor))
                                    .opacity(flashKind != nil ? 0.3 : 0)
                                    .padding(-16)
                            )
                            .overlay(alignment: .leading) {
                                if flashKind != nil && flashKind == .deduped {
                                    Image(systemName: "rectangle.on.rectangle.dashed")
                                        .font(.headline)
                                        .foregroundStyle(Color(hex: list.hexColor))
                                        .background(Circle().fill(Color(.systemBackground)))
                                        .overlay(Circle().stroke(Color(.separator).opacity(0.75), lineWidth: 1))
                                        .accessibilityHidden(true)
                                }
                            }
                            .sensoryFeedback(.success, trigger: flashTrigger)
                            .sensoryFeedback(.impact(weight: .light), trigger: flashTrigger)
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
                },
                header: {
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
                                addingToListID = list.id
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(Color(hex: list.hexColor))
                                .accessibilityLabel(Text("Add a new Bethinkery to the \(list.title) list"))
                        }
                    }
                    .id(list.id)
                })
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

    private func doBethinkeryMove(_ bethinkery: Bethinkery,
                                  destination: BethinkeryList,
                                  inheritListAlarms: Bool) throws {
        try bethinkeryModel.moveBethinkery(bethinkery,
                                           to: destination,
                                           inheritListAlarms: inheritListAlarms)
    }

    private func flash(_ id: String, kind: RowFlashKind) {
        Task { @MainActor in
            flashedRow = (id, kind)
            flashTrigger += 1

            try? await Task.sleep(for: .milliseconds(100))
            guard flashedRow?.id == id else { return }
            withAnimation(.snappy(duration: 1)) {
                flashedRow = nil
            }
        }
        if kind == .deduped {
            // TODO: accessibility review
            AccessibilityNotification.Announcement("Already on list, moved to top").post()
        }
    }

    private func requestBethinkeryMove(_ bethinkery: Bethinkery, destination: BethinkeryList) throws {
        if bethinkery.hasAlarms {
            if destination.hasAlarms {
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
                alertDialogModel.present(title: "Moving Reminder",
                                         // swiftlint:disable:next line_length
                                         message: "This Reminder has alarms and is being moved to a List with different alarms. Do you want to discard the existing alarms and replace them with the alarms from the new list?",
                                         actions: actions,
                                         currentAlarms: bethinkery.alarms.compactMap({ $0.toTemplate() }),
                                         diffAlarms: destination.alarmTemplates.compactMap({ $0.toTemplate() }))
            } else {
                // retain existing alarms and don't inherit []
                try doBethinkeryMove(bethinkery, destination: destination, inheritListAlarms: false)
            }
        } else {
            try doBethinkeryMove(bethinkery, destination: destination, inheritListAlarms: true)
        }
    }
}
