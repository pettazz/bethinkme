import SwiftUI


struct AddBethinkeryRowView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = kEnableAutocorrectDefault
    @AppStorage(SettingsKey.enableDedupe.rawValue)
    private var enableDedupe: Bool = kEnableDedupeDefault
    @AppStorage(SettingsKey.dedupeCaseSensitive.rawValue)
    private var dedupeCaseSensitive: Bool = kDedupeCaseSensitiveDefault

    @FocusState private var addInFocus: Bool
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
                                enableAutocorrect: enableAutocorrectSetting) {
                saveNew()
                scrollToAdd()
            } onDone: {
                saveNew()
                closeAdding()
            }
                .id("adding-to-\(list.id)")
                .focused($addInFocus)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            closeAdding()
                        }
                    }
                }
                .onAppear {
                    Task { @MainActor in
                        await Task.yield()
                        guard isAdding else { return }
                        addInFocus = true
                        scrollToAdd()
                    }
                }
        }
        .onChange(of: addInFocus) { _, isFocused in
            guard !isFocused, isAdding else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                if !addInFocus {
                    closeAdding()
                } else {
                    scrollToAdd()
                }
            }
        }
    }

    private func scrollToAdd() {
        guard isAdding, let scrollProxy else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation {
                let visible = list.visibleBethinkeries(showCompleted: sharedModel.showCompleted)
                if visible.count >= 2 {
                    scrollProxy.scrollTo(visible[1].id, anchor: .bottom)
                } else if let first = visible.first {
                    scrollProxy.scrollTo(first.id, anchor: .bottom)
                } else {
                    scrollProxy.scrollTo("adding-to-\(list.id)", anchor: .top)
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
                let newBethinkery = EditBethinkery(title: cleanTitle, isCompleted: false)
                let createdBethinkery = try bethinkeryModel.create(from: newBethinkery, list: list)
                onFlash(createdBethinkery.id, .created)
            }
        }
        newTitle = ""
    }

    private func closeAdding() {
        withAnimation {
            newTitle = ""
            if addingToListID == list.id {
                addingToListID = nil
            }
            addInFocus = false
        }
    }
}
