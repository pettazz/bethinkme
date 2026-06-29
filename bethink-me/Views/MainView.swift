import EventKit
import SwiftData
import SwiftUI


struct MainView: View {
    @AppStorage(SettingsKey.maxCompletedAgeDays.rawValue)
    private var maxCompletedAgeDaysSetting: Int = 7

    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.scenePhase)
    private var scenePhase

    @State private var sharedModel: SharedViewModel?
    @State private var listModel: ListViewModel?
    @State private var bethinkeryModel: BethinkeryViewModel?

    @State private var listEditMode: EditMode = .inactive
    @State private var shouldPresentNewListSheet = false

    @State private var listsLoading: Bool = false
    @State private var listsLoadingTime: Int = 0
    @State private var showDelayedSpinner = false

    @State private var selectedBethinkeryForEdit: Bethinkery?

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if sharedModel != nil && listModel != nil && bethinkeryModel != nil {
                        if !sharedModel!.hasAccess {
                            VStack {
                                Spacer()
                                Image(systemName: "hand.raised.square.on.square")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                    .accessibilityHidden(true)
                                Text("No Permission")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text("u gotta let me look at them toedeos")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Link("Enable me in settings!",
                                     destination: URL(string: UIApplication.openSettingsURLString)!)
                                Spacer()
                            }
                        } else if sharedModel!.bethinkeryLists.isEmpty {
                            VStack {
                                Spacer()
                                Image(systemName: "checklist")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                    .accessibilityHidden(true)
                                Text("oh no")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text("no toedeos?")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(sharedModel!.bethinkeryLists) { list in
                                    ListView(
                                        selectedBethinkeryForEdit: $selectedBethinkeryForEdit,
                                        sharedModel: sharedModel!,
                                        listModel: listModel!,
                                        bethinkeryModel: bethinkeryModel!,
                                        list: list
                                    )
                                }
                                .onMove { from, to in
                                    listModel!.moveListPosition(from: from, to: to)
                                }
                                .onDelete { offsets in
                                    withErrorReporter {
                                        // TODO: confirmation dialog?
                                        guard offsets.count == 1 else {
                                            throw BethinkMeError("tried to delete multiple list offsets: \(offsets)")
                                        }
                                        try listModel!.delete(sharedModel!.bethinkeryLists[offsets.first!])
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
                                    }
                                    sharedModel!.resetOrdinals()
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
                        LoadingSpinnerView()
                            .glassEffect(in: .rect(cornerRadius: 16.0))
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

        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            try? await setupVMs()
            let coordinator = sharedModel!.syncCoordinator
            if !coordinator.hasEverSynced {
                await tryTask(Task {
                    await coordinator.requestSync(reason: .initialized)
                })
            } else if coordinator.shouldPerformForegroundedSync {
                await coordinator.requestSync(reason: .foregrounded)
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
