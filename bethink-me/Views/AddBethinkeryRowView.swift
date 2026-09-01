import SwiftUI

enum SaveAndThen {
    case keepEditing
    case close
}

struct AddBethinkeryRowView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = kEnableAutocorrectDefault
    @AppStorage(SettingsKey.enableDedupe.rawValue)
    private var enableDedupe: Bool = kEnableDedupeDefault
    @AppStorage(SettingsKey.dedupeCaseSensitive.rawValue)
    private var dedupeCaseSensitive: Bool = kDedupeCaseSensitiveDefault
    @AppStorage(SettingsKey.sortType.rawValue)
    private var sortType: BethinkerySorting = kSortTypeDefault

    @State private var addInFocus: Bool = true
    @State private var newTitle: String = ""
    @State private var lastDuplicatedTitle: String = ""

    @State private var shouldDisplayDupePopover = false
    @State private var dupePopoverTimeout: Task<Void, Never>?

    var list: BethinkeryList

    var sharedModel: SharedViewModel
    var bethinkeryModel: BethinkeryViewModel

    var scrollProxy: ScrollViewProxy?

    @Binding var addingToListID: String?

    var onFlash: (String, RowFlashKind) -> Void

    private var isAdding: Bool {
        addingToListID == list.id
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(.gray)
                .accessibilityHidden(true)
            RepeatableTextField(text: $newTitle,
                                isFocused: $addInFocus,
                                enableAutocorrect: enableAutocorrectSetting,
                                onSubmit: {
                                    save(next: .keepEditing)
                                },
                                onDone: {
                                    save(next: .close)
                                    closeAdding()
                                },
                                onCancel: {
                                    if isAdding {
                                        closeAdding()
                                    }
                                },
                                onEndEditing: {
                                    if isAdding {
                                        closeAdding()
                                    }
                                })
                .onAppear {
                    addInFocus = true
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIResponder.keyboardDidShowNotification)) { _ in
                        guard isAdding && addInFocus else { return }
                        scrollToAdd()
                }
        }
        .id("adding-to-\(list.id)")
        .popover(isPresented: $shouldDisplayDupePopover) {
            Text("Already on list, type again to add another")
//                .font(.footnote)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }

    private func scrollToAdd(completion: (() -> Void)? = nil) {
        let visible = list.visibleBethinkeries(showCompleted: sharedModel.showCompleted, sortedBy: sortType)

        if visible.count >= 2 {
            scrollTo(id: visible[1].id, completion: completion)
        } else if let first = visible.first {
            scrollTo(id: first.id, completion: completion)
        } else {
            scrollTo(id: "adding-to-\(list.id)", completion: completion)
        }
    }

    private func scrollTo(id: String, completion: (() -> Void)? = nil) {
        guard let scrollProxy else { return }

        DispatchQueue.main.async {
            withAnimation(.default, completionCriteria: .removed) {
                scrollProxy.scrollTo(id, anchor: .bottom)
            } completion: {
                completion?()
            }
        }
    }

    private func save(next: SaveAndThen) {
        withErrorReporter {
            let cleanTitle = newTitle.trimmingCharacters(in: .whitespaces)
            guard !cleanTitle.isEmpty else { return }

            let bethinkeries = list.visibleBethinkeries(showCompleted: sharedModel.showCompleted, sortedBy: sortType)
            if enableDedupe, let dupeIdx = bethinkeries.firstIndex(where: { bethinkery in
                let titleText = dedupeCaseSensitive ? bethinkery.title : bethinkery.title.lowercased()
                let newText = dedupeCaseSensitive ? cleanTitle : cleanTitle.lowercased()
                let lastText = dedupeCaseSensitive ? lastDuplicatedTitle : lastDuplicatedTitle.lowercased()

                return !bethinkery.isCompleted &&
                        titleText == newText &&
                        titleText != lastText
            }) {
                // dupe found, pop it to the top (if custom sorted) and ignore the new one
                let dupeID = bethinkeries[dupeIdx].id
                if sortType != .custom && next == .keepEditing {
                    dupePopoverTimeout?.cancel()
                    shouldDisplayDupePopover = true
                    dupePopoverTimeout = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(20))
                        guard !Task.isCancelled else { return }
                        shouldDisplayDupePopover = false
                    }
                } else {
                    try bethinkeryModel.moveBethinkeryPosition(from: IndexSet(integer: dupeIdx), to: 0, list: list)
                }
                lastDuplicatedTitle = cleanTitle
                if next == .close {
                    scrollTo(id: dupeID) {
                        onFlash(dupeID, .deduped)
                    }
                } else {
                    scrollToAdd {
                        onFlash(dupeID, .deduped)
                    }
                }
            } else {
                // no existing dupe, continue adding new
                lastDuplicatedTitle = ""
                let newBethinkery = EditBethinkery(title: cleanTitle, isCompleted: false)
                let createdBethinkery = try bethinkeryModel.create(from: newBethinkery, list: list, sortedBy: sortType)

                if next == .close {
                    scrollTo(id: createdBethinkery.id) {
                        onFlash(createdBethinkery.id, .created)
                    }
                } else {
                    scrollToAdd {
                        onFlash(createdBethinkery.id, .created)
                    }
                }
            }
        }

        newTitle = ""
    }

    private func closeAdding() {
        addInFocus = false
        newTitle = ""
        if addingToListID == list.id {
            addingToListID = nil
        }
        dupePopoverTimeout?.cancel()
        shouldDisplayDupePopover = false
    }
}
