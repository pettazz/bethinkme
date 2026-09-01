import SwiftUI


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
                                    saveNew()
                                    scrollToAdd()
                                },
                                onDone: {
                                    saveNew()
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
    }

    private func scrollToAdd() {
        guard let scrollProxy else { return }

        DispatchQueue.main.async {
            withAnimation {
                let visible = list.visibleBethinkeries(showCompleted: sharedModel.showCompleted, sortedBy: sortType)

                if visible.count >= 2 {
                    scrollProxy.scrollTo(visible[1].id, anchor: .bottom)
                } else if let first = visible.first {
                    scrollProxy.scrollTo(first.id, anchor: .bottom)
                } else {
                    scrollProxy.scrollTo("adding-to-\(list.id)", anchor: .bottom)
                }
            }
        }
    }

    private func saveNew() {
        withErrorReporter {
            let cleanTitle = newTitle.trimmingCharacters(in: .whitespaces)
            guard !cleanTitle.isEmpty else { return }

            let bethinkeries = list.visibleBethinkeries(showCompleted: sharedModel.showCompleted)
            if enableDedupe, let dupeIdx = bethinkeries.firstIndex(where: { bethinkery in
                let titleText = dedupeCaseSensitive ? bethinkery.title : bethinkery.title.lowercased()
                let newText = dedupeCaseSensitive ? cleanTitle : cleanTitle.lowercased()
                let lastText = dedupeCaseSensitive ? lastDuplicatedTitle : lastDuplicatedTitle.lowercased()

                return !bethinkery.isCompleted &&
                        titleText == newText &&
                        titleText != lastText
            }) {
                // dupe found, pop it to the top and ignore the new one
                let dupeID = bethinkeries[dupeIdx].id
                try bethinkeryModel.moveBethinkeryPosition(from: IndexSet(integer: dupeIdx), to: 0, list: list)
                lastDuplicatedTitle = cleanTitle
                onFlash(dupeID, .deduped)
            } else {
                // no existing dupe, continue adding new
                lastDuplicatedTitle = ""
                let newBethinkery = EditBethinkery(title: cleanTitle, isCompleted: false)
                let createdBethinkery = try bethinkeryModel.create(from: newBethinkery, list: list)
                onFlash(createdBethinkery.id, .created)
            }
        }
        newTitle = ""
    }

    private func closeAdding() {
        newTitle = ""
        if addingToListID == list.id {
            addingToListID = nil
        }
        addInFocus = false
    }
}
