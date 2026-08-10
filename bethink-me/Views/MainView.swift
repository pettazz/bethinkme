import EventKit
import SwiftData
import SwiftUI


struct MainView: View {
    @AppStorage(SettingsKey.maxCompletedAgeDays.rawValue)
    private var maxCompletedAgeDaysSetting: Int = kMaxCompletedAgeDaysDefault
    @AppStorage(SettingsKey.enableDedupe.rawValue)
    private var enableDedupe: Bool = kEnableDedupeDefault
    @AppStorage(SettingsKey.dedupeNow.rawValue)
    private var dedupeNow: Bool = false

    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.scenePhase)
    private var scenePhase

    @State private var sharedModel: SharedViewModel?
    @State private var listModel: ListViewModel?
    @State private var bethinkeryModel: BethinkeryViewModel?

    @State private var errorState = ErrorState.instance

    @State private var isSyncing: Bool = false
    @State private var showDelayedSpinner = false

    @State private var selectedBethinkeryForEdit: Bethinkery?

    @State private var alertDialogModel: AlertDialogModel = AlertDialogModel()

    private var isLoadingInit: Bool {
        sharedModel == nil || listModel == nil || bethinkeryModel == nil
    }

    private var isLoadingAny: Bool {
        sharedModel == nil || listModel == nil || bethinkeryModel == nil || isSyncing
    }

    private var loadingMessage: String? {
        if isSyncing {
            return "Synchronizing Bethinkeries.."
        }
        if isLoadingInit {
            return "Loading Bethinkeries..."
        }

        return nil
    }

    var body: some View {
        ZStack {
            NavigationStack {
                if let sharedModel, !sharedModel.hasAccess {
                        InvalidStateView(icon: "hand.raised.square.on.square",
                                         title: "No Permission",
                                         message: "u gotta let me look at them toedeos",
                                         linkTitle: "Enable me in settings!")
                } else if let sharedModel, sharedModel.syncStatus == .unavailable {
                    InvalidStateView(icon: "wifi.exclamationmark",
                                     title: "Can't connect to Reminders",
                                     message: "One or more of your accounts may be offline",
                                     retry: {
                                         let coordinator = sharedModel.syncCoordinator
                                         coordinator.requestSync(reason: .initialized)
                                     })

                } else {
                    ZStack {
                        if let sharedModel, let listModel, let bethinkeryModel {
                            ListsView(sharedModel: sharedModel,
                                      listModel: listModel,
                                      bethinkeryModel: bethinkeryModel,
                                      isLoadingAny: isLoadingAny,
                                      selectedBethinkeryForEdit: $selectedBethinkeryForEdit)
                        }

                        ZStack {
                            if showDelayedSpinner, let msg = loadingMessage {
                                spinnerContent(message: msg)
                            }
                        }
                        .animation(.snappy, value: showDelayedSpinner)
                        .task(id: isLoadingAny) {
                            guard isLoadingAny else {
                                showDelayedSpinner = false
                                return
                            }
                            try? await Task.sleep(for: .seconds(1))
                            guard !Task.isCancelled, isLoadingAny else { return }

                            withAnimation(.snappy) {
                                showDelayedSpinner = true
                            }
                        }
                    }
                }
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                do {
                    try await setupVMs()
                } catch {
                    ErrorReporter().report(error, retry: {
                        try await setupVMs()
                    })
                }

                guard let sharedModel else { return }
                if sharedModel.hasAccess {
                    let coordinator = sharedModel.syncCoordinator
                    coordinator.requestSync(reason: coordinator.hasEverSynced ? .foregrounded : .initialized)
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
                                 message: activeError.error.message,
                                 retry: ErrorState.instance.doRetry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
        .onChange(of: maxCompletedAgeDaysSetting) { _, _ in
            Task {
                guard let sharedModel else { return }
                sharedModel.syncCoordinator.requestSync(reason: .EKChanged)
            }
        }
        .onChange(of: enableDedupe) { _, isDedupeEnabled in
            guard isDedupeEnabled, let listModel else { return }
            let dupes = listModel.findAllDuplicates()
            guard !dupes.isEmpty else { return }
            displayDedupeConfirmation(dupes: dupes)
        }
        .onAppear {
            guard enableDedupe && dedupeNow, let listModel else { return }
            dedupeNow = false
            let dupes = listModel.findAllDuplicates()
            guard !dupes.isEmpty else { return }
            displayDedupeConfirmation(dupes: dupes)
        }
        .environment(alertDialogModel)
        .alertDialogPresentable(alertModel: $alertDialogModel)
    }

    @ViewBuilder
    private func spinnerContent(message: String) -> some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        if #available(iOS 26.0, *) {
            LoadingSpinnerView(message: message)
                .glassEffect(in: .rect(cornerRadius: 16.0))
        } else {
            LoadingSpinnerView(message: message)
                .background(RoundedRectangle(cornerRadius: 16.0)
                    .fill(Color.white))
        }
    }

    private func setupVMs() async throws {
        if sharedModel == nil {
            sharedModel = await SharedViewModel(modelContext: modelContext)
        }
        guard let sharedModel else { throw BethinkMeError("failed to set up Shared ViewModel") }
        if listModel == nil {
            listModel = ListViewModel(sharedModel: sharedModel)
        }
        guard let listModel else { throw BethinkMeError("failed to set up List ViewModel") }
        if bethinkeryModel == nil {
            bethinkeryModel = BethinkeryViewModel(sharedModel: sharedModel)
        }
        guard bethinkeryModel != nil else { throw BethinkMeError("failed to set up Bethinkery ViewModel") }

        if sharedModel.syncCoordinator.synchronizer == nil {
            sharedModel.syncCoordinator.synchronizer = {
                isSyncing = true
                try await listModel.loadLists()
                isSyncing = false
            }
            sharedModel.syncCoordinator.start()
            sharedModel.startEventStoreObserver()
        }
    }

    private func displayDedupeConfirmation(dupes: DuplicateGroup) {
        let actions = [
            ActionButton(title: "Remove duplicate Reminders", role: .destructive, action: {
                withErrorReporter {
                    guard let bethinkeryModel else {
                        throw BethinkMeError("lost access to model when trying to run cleanup dedupe")
                    }
                    try bethinkeryModel.delete(dupes.allBethinkeries)
                }
            }),
            ActionButton(title: "Leave them alone", role: .cancel, action: {})
        ]
        alertDialogModel.present(title: "Duplicate Reminders",
                                 // swiftlint:disable:next line_length
                                 message: "You've enabled deduplication for new reminders, do you want to find and remove existing duplicates in your lists now? Any identical reminders within the same list will be **permanently** deleted, leaving only one copy.",
                                 actions: actions,
                                 duplicateList: dupes,
                                 showDefaultCancel: false)
    }
}
