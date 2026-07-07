import EventKit
import SwiftData
import SwiftUI


struct MainView: View {
    @AppStorage(SettingsKey.maxCompletedAgeDays.rawValue)
    private var maxCompletedAgeDaysSetting: Int = kMaxCompletedAgeDaysDefault

    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.scenePhase)
    private var scenePhase

    @State private var sharedModel: SharedViewModel?
    @State private var listModel: ListViewModel?
    @State private var bethinkeryModel: BethinkeryViewModel?

    @State private var errorState = ErrorState.instance

    @State private var listEditMode: EditMode = .inactive
    @State private var shouldPresentNewListSheet = false

    @State private var listsLoading: Bool = false
    @State private var showDelayedSpinner = false

    @State private var selectedBethinkeryForEdit: Bethinkery?

    @State private var isPresentingDeleteConfirmation: Bool = false
    @State private var selectedListForDelete: BethinkeryList?

    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    VStack {
                        if sharedModel != nil && listModel != nil && bethinkeryModel != nil {
                            if !sharedModel!.hasAccess {
                                InvalidStateView(icon: "hand.raised.square.on.square",
                                                 title: "No Permission",
                                                 message: "u gotta let me look at them toedeos",
                                                 linkTitle: "Enable me in settings!")
                            } else if sharedModel!.bethinkeryLists.isEmpty {
                                InvalidStateView(icon: "checklist",
                                                 title: "oh no",
                                                 message: "no toedoes?")
                            } else {
                                List {
                                    ForEach(sharedModel!.bethinkeryLists) { list in
                                        ListView(
                                            selectedBethinkeryForEdit: $selectedBethinkeryForEdit,
                                            sharedModel: sharedModel!,
                                            listModel: listModel!,
                                            bethinkeryModel: bethinkeryModel!,
                                            list: list,
                                            onListDelete: { list in
                                                selectedListForDelete = list
                                                isPresentingDeleteConfirmation = true
                                            }
                                        )
                                    }
                                    .onMove { from, to in
                                        withErrorReporter {
                                            try listModel!.moveListPosition(from: from, to: to)
                                        }
                                    }
                                }
                                .environment(\.editMode, $listEditMode)
                            }
                        }
                    }
                    .navigationTitle("Lists")
                    .toolbar {
                        if sharedModel != nil && listModel != nil {
                            if listEditMode != .active {
                                ToolbarItem(placement: .primaryAction) {
                                    Button {
                                        shouldPresentNewListSheet.toggle()
                                    } label: {
                                        Image(systemName: "rectangle.stack.fill.badge.plus")
                                            .accessibilityLabel(Text("Add a new list"))
                                    }
                                    .sheet(isPresented: $shouldPresentNewListSheet, content: {
                                        ListDetailView(sharedModel: sharedModel!, listModel: listModel!)
                                            .textCase(.none)
                                    })
                                    .disabled(listsLoading)
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
                                .disabled(listsLoading)
                            }
                            if listEditMode != .active {
                                ToolbarItem(placement: .primaryAction) {
                                    Button {
                                        withAnimation {
                                            sharedModel!.showCompleted.toggle()
                                            sharedModel!.reload()
                                            sharedModel!.resetOrdinals()
                                        }
                                    } label: {
                                        if sharedModel!.showCompleted {
                                            Image(systemName: "eye.slash.fill")
                                                .accessibilityLabel(Text("Hide completed Bethinkeries"))
                                        } else {
                                            Image(systemName: "eye.fill")
                                                .accessibilityLabel(Text("Show completed Bethinkeries"))
                                        }
                                    }
                                    .disabled(listsLoading)
                                }
                            }
                        }
                    }

                    ZStack {
                        if showDelayedSpinner {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            if #available(iOS 26.0, *) {
                                LoadingSpinnerView()
                                    .glassEffect(in: .rect(cornerRadius: 16.0))
                            } else {
                                LoadingSpinnerView()
                                    .background(RoundedRectangle(cornerRadius: 16.0)
                                        .fill(Color.white))
                            }
                        }
                    }
                    .animation(.snappy, value: showDelayedSpinner)
                    .task(id: listsLoading) {
                        showDelayedSpinner = false

                        guard listsLoading else { return }
                        try? await Task.sleep(for: .seconds(1))
                        guard !Task.isCancelled, listsLoading else { return }

                        withAnimation(.snappy) {
                            showDelayedSpinner = true
                        }
                    }
                }
            }
            .confirmationDialog("Are you sure?",
                                isPresented: $isPresentingDeleteConfirmation) {
                Button("Delete List", role: .destructive) {
                    guard selectedListForDelete != nil else { return }
                    withErrorReporter {
                        try listModel!.delete(selectedListForDelete!)
                    }
                    isPresentingDeleteConfirmation = false
                    selectedListForDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    isPresentingDeleteConfirmation = false
                    selectedListForDelete = nil
                }
            } message: {
                // swiftlint:disable:next line_length
                Text("Are you sure you want to delete **\(selectedListForDelete?.title ?? "this list")** and all Reminders on it? This cannot be undone.")
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                try? await setupVMs()
                if sharedModel!.hasAccess {
                    let coordinator = sharedModel!.syncCoordinator
                    if !coordinator.hasEverSynced {
                        Task {
                            await coordinator.requestSync(reason: .initialized)
                        }
                    } else if coordinator.shouldPerformForegroundedSync {
                        await coordinator.requestSync(reason: .foregrounded)
                    }
                }
            }
            .sheet(item: $selectedBethinkeryForEdit) { bethinkery in
                if let bethinkeryModel {
                    BethinkeryDetailView(
                        bethinkeryModel: bethinkeryModel,
                        bethinkery: bethinkery
                    )
                    .id(bethinkery.id)
                }
            }
            .disabled(errorState.currentError != nil)

            if let activeError = errorState.currentError {
                InvalidStateView(icon: "exclamationmark.triangle.fill",
                                 title: "We've run into an error",
                                 message: activeError.error.message)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
        .onChange(of: maxCompletedAgeDaysSetting) { _, _ in
            Task {
                guard let sharedModel else { return }
                guard sharedModel.syncCoordinator.synchronizer != nil else { return }
                try await sharedModel.syncCoordinator.synchronizer!()
            }
        }

    }

    private func setupVMs() async throws {
        if sharedModel == nil {
            sharedModel = await SharedViewModel(modelContext: modelContext)
        }
        if listModel == nil {
            listModel = ListViewModel(sharedModel: sharedModel!)
        }
        if bethinkeryModel == nil {
            bethinkeryModel = BethinkeryViewModel(sharedModel: sharedModel!)
        }
        if sharedModel!.syncCoordinator.synchronizer == nil {
            sharedModel!.syncCoordinator.synchronizer = { [listModel = listModel!] in
                listsLoading = true
                try await listModel.loadLists()
                listsLoading = false
            }
            sharedModel!.startEventStoreObserver()
        }
    }
}
