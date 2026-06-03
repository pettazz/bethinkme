import Combine
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

    @State private var model: ViewModel?
    @State private var listEditMode: EditMode = .inactive
    @State private var shouldPresentNewListSheet = false
    @State private var selectedBethinkeryForEdit: Bethinkery?

    @State private var listsLoading: Bool = false
    @State private var listsLoadingTime: Int = 0
    
    private var clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if model != nil {
                        if !model!.hasAccess {
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
                        } else if model!.bethinkeryLists.isEmpty {
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
                                ForEach(model!.bethinkeryLists) { list in
                                    BethinkeryListView(
                                        model: model!,
                                        list: list,
                                        selectedBethinkeryForEdit: $selectedBethinkeryForEdit
                                    )
                                }
                                .onMove { from, to in
                                    model!.moveListPosition(from: from, to: to)
                                }
                                .onDelete { offsets in
                                    withErrorReporter {
                                        // TODO: confirmation dialog?
                                        guard offsets.count == 1 else {
                                            throw BethinkMeError("tried to delete multiple list offsets: \(offsets)")
                                        }
                                        try model!.delete(model!.bethinkeryLists[offsets.first!])
                                    }
                                }
                            }
                            .sheet(item: $selectedBethinkeryForEdit) { item in
                                BethinkeryDetailView(
                                    model: model!,
                                    bethinkery: item
                                )
                                .textCase(.none)
                            }
                            .environment(\.editMode, $listEditMode)
                        }
                    }
                }
                .navigationTitle("Lists")
                .toolbar {
                    if model != nil {
                        if listEditMode != .active {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    shouldPresentNewListSheet.toggle()
                                } label: {
                                    Image(systemName: "rectangle.stack.fill.badge.plus")
                                        .accessibilityLabel(Text("Add a new list"))
                                }
                                .sheet(isPresented: $shouldPresentNewListSheet, content: {
                                    ListDetailView(model: model!)
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
                                        model!.showCompleted.toggle()
                                    }
                                    model!.resetOrdinals()
                                } label: {
                                    if model!.showCompleted {
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
                    if listsLoadingTime >= 1 && listsLoading {
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
                }.animation(.snappy, value: listsLoading)
                
            }
            .onReceive(clock) { _ in
                withAnimation(.snappy) {
                    listsLoadingTime = listsLoading ? listsLoadingTime + 1 : 0
                }
            }
        }
        
        .task(id: scenePhase) {
            if scenePhase == .active {
                await tryTask(Task { try await reloadLists() })
            }
        }
        .task {
            guard model == nil else { return }
            model = await ViewModel(modelContext: modelContext)
        }
    }
    
    func reloadLists() async throws {
        guard model != nil else {
            throw BethinkMeError("tried to reloadLists with no viewModel instantiated")
        }
        
        listsLoading = true
        try await model!.loadLists()
        listsLoading = false
    }
}

struct LoadingSpinnerView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .tint(.accentColor)
                .scaleEffect(2.0, anchor: .center)
                .padding()
            Text("Loading Bethinkeries...")
                .padding()
        }
        .padding()
        .transition(.blurReplace)
    }
}

struct BethinkeryListView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true
    
    @Environment(\.editMode)
    private var editMode

    @FocusState private var addInFocus: Bool
    
    @State var model: ViewModel
    @State var list: BethinkeryList
    @State private var isAdding: Bool = false
    @State private var newTitle: String = ""
    @State private var shouldPresentEditListSheet = false
    @Binding var selectedBethinkeryForEdit: Bethinkery?

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
                    BethinkeryRowView(model: model, bethinkery: bethinkery)
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

struct BethinkeryRowView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true
    @AppStorage(SettingsKey.displayNotes.rawValue)
    private var displayNotes: Bool = false
    @AppStorage(SettingsKey.displayURLs.rawValue)
    private var displayURLs: Bool = false
    
    @FocusState private var editFocus: Bool
    
    @State var model: ViewModel
    @State var bethinkery: Bethinkery
    @State private var isEditing: Bool = false
    @State private var editedTitle: String = ""
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isEditing {
                Image(systemName: "pencil.line")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .accessibilityHidden(true)
            } else {
                Button {
                    withAnimation {
                        withErrorReporter {
                            try model.toggleCompleted(bethinkery)
                        }
                    }
                } label: {
                    Image(systemName: bethinkery.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(bethinkery.isCompleted ? .green : .gray)
                        .accessibilityLabel(Text(bethinkery.isCompleted
                                                 ? "Completed"
                                                 : "Not completed"))
                }
                .sensoryFeedback(.success, trigger: bethinkery.isCompleted)
            }
            
            if isEditing {
                TextField(bethinkery.title, text: $editedTitle)
                    .autocorrectionDisabled(!enableAutocorrectSetting)
                    .focused($editFocus)
                    .onAppear {
                        editFocus = true
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                cancelEdit()
                            }
                        }
                        ToolbarItem(placement: .keyboard) {
                            Spacer()
                        }
                        ToolbarItem(placement: .keyboard) {
                            Button("Done") {
                                saveEdit()
                            }
                        }
                    }
                    .onSubmit {
                        saveEdit()
                    }
                    .onChange(of: editFocus) {
                        if !editFocus {
                            saveEdit()
                        }
                    }
                
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(bethinkery.title)
                        .strikethrough(bethinkery.isCompleted)
                        .foregroundColor(bethinkery.isCompleted ? .gray : .primary)
                        .onTapGesture {
                            editedTitle = bethinkery.title
                            isEditing = true
                        }
                        .accessibilityAddTraits(.isButton)
                    if !bethinkery.isCompleted {
                        if displayNotes && bethinkery.hasNotes {
                            Text(bethinkery.notes!)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        if displayURLs && bethinkery.hasUrl {
                            Link(bethinkery.url!.absoluteString, destination: bethinkery.url!)
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func cancelEdit() {
        editedTitle = ""
        isEditing = false
    }
    
    private func saveEdit() {
        withErrorReporter {
            var updater = EditBethinkery.fromBethinkery(bethinkery)
            updater.title = editedTitle
            try model.update(bethinkery, with: updater)
        }
        
        cancelEdit()
    }
}

struct ListDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true
    
    @Environment(\.dismiss)
    private var dismiss

    @State var model: ViewModel
    @State private var title: String = ""
    @State private var newTitle: String = ""
    @State private var newColor: Color = Color.accentColor
    @State private var newSourceId: String = ""
    
    var list: BethinkeryList?

    private var isNew: Bool { list == nil }
    
    private var selectedSource: EKSource? {
        model.availableSources.first(where: { $0.sourceIdentifier == newSourceId })
    }
    
    var body: some View {
        if !model.availableSources.isEmpty {
            // TODO: make this less ugly, see also BethinkeryDetailView
            NavigationView {
                VStack {
                    Text(newTitle.isEmpty ? "New List" : newTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(newColor)
                        .font(.largeTitle)
                        .bold()
                        .padding(20)
                    Form {
                        Section {
                            TextField(title, text: $newTitle)
                                .autocorrectionDisabled(!enableAutocorrectSetting)
                            ColorPicker("List color", selection: $newColor)
                            if isNew {
                                Picker("Save to", selection: $newSourceId) {
                                    ForEach(model.availableSources, id: \.sourceIdentifier) { source in
                                        Text(source.title).tag(source.sourceIdentifier)
                                    }
                                }
                            }
                            
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            withAnimation {
                                withErrorReporter {
                                    if isNew {
                                        let creator = EditBethinkeryList(title: newTitle, hexColor: newColor.toHex())
                                        guard selectedSource != nil else {
                                            throw BethinkMeError("tried to create a List on a nonexistent Source")
                                        }
                                        try model.createList(from: creator, source: selectedSource!)
                                    } else {
                                        var updater = EditBethinkeryList.fromBethinkeryList(list!)
                                        updater.title = newTitle
                                        updater.hexColor = newColor.toHex()
                                        try model.update(list!, with: updater)
                                    }
                                }
                            }
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                
            }
            .task {
                if isNew {
                    title = "New List"
                    newSourceId = model.defaultSource?.sourceIdentifier ??
                        model.availableSources.first?.sourceIdentifier ??
                        ""
                } else {
                    title = list!.title
                    newTitle = list!.title
                    newColor = Color(hex: list!.hexColor)
                }
            }
        } else {
            NavigationStack {
                VStack {
                    Spacer()
                    Image(systemName: "text.badge.xmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)
                    Text("No Sources")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("You have nowhere to save Reminders!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Link("Add an account in Settings!",
                         destination: URL(string: UIApplication.openSettingsURLString)!)
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct BethinkeryDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true
    
    @Environment(\.dismiss)
    private var dismiss

    @State var model: ViewModel
    @State var editBethinkeryCommand: EditBethinkery

    var bethinkery: Bethinkery

    var notesBinding: Binding<String> {
        Binding<String>(
            get: {
                return editBethinkeryCommand.notes ?? ""
            },
            set: { newString in
                let cleanedString = newString.trimmingCharacters(in: .whitespacesAndNewlines)
                editBethinkeryCommand.notes = cleanedString.isEmpty ? nil : cleanedString
            }
        )
    }
    var urlBinding: Binding<String> {
        Binding<String>(
            get: {
                return editBethinkeryCommand.url?.absoluteString ?? ""
            },
            set: { newString in
                let cleanedString = newString.trimmingCharacters(in: .whitespacesAndNewlines)
                editBethinkeryCommand.url = cleanedString.isEmpty ? nil : URL(string: newString)
            }
        )
    }

    init(model: ViewModel, bethinkery: Bethinkery) {
        self.model = model
        self.bethinkery = bethinkery
        self.editBethinkeryCommand = EditBethinkery.fromBethinkery(bethinkery)
    }

    var body: some View {
        NavigationView {
            VStack {
                // TODO: make this less ugly, see also ListDetailView
                Text(editBethinkeryCommand.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(Color(hex: bethinkery.list.hexColor))
                    .font(.largeTitle)
                    .bold()
                    .padding(20)
                Form {
                    Section {
                        TextField(
                            editBethinkeryCommand.title,
                            text: $editBethinkeryCommand.title,
                            prompt: Text("Title")
                        )
                        .autocorrectionDisabled(!enableAutocorrectSetting)

                        TextField(
                            editBethinkeryCommand.notes ?? "",
                            text: notesBinding,
                            prompt: Text("Notes"),
                            axis: .vertical
                        )

                        TextField(
                            editBethinkeryCommand.url?.absoluteString ?? "",
                            text: urlBinding,
                            prompt: Text("URL")

                        )
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        withAnimation {
                            withErrorReporter {
                                try model.update(bethinkery, with: editBethinkeryCommand)
                            }
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
