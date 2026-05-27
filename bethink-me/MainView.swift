import Combine
import EventKit
import SwiftData
import SwiftUI


struct MainView: View {
    @AppStorage(SettingsKey.maxCompletedAgeDays.rawValue)
    private var maxCompletedAgeDaysSetting: Int = 7
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var model: ViewModel?
    @State private var listEditMode: EditMode = .inactive
    @State private var shouldPresentNewListSheet = false
    
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
                        } else if (model!.bethinkeryLists.isEmpty) {
                            VStack {
                                Spacer()
                                Image(systemName: "checklist")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
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
                                    BethinkeryListView(model: model!, list: list)
                                }
                                .onMove { from, to in
                                    model!.moveList(from: from, to: to)
                                }
                                .onDelete { offsets in
                                    // TODO: confirmation dialog
                                    guard offsets.count == 1 else {
                                        // impossible on iOS!
                                        print("invalid number of offsets sent to delete list!")
                                        return
                                    }
                                    model!.delete(bethinkeryList: model!.bethinkeryLists[offsets.first!])
                                }
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
                                    } else {
                                        Image(systemName: "eye.fill")
                                    }
                                }
                                .disabled(listsLoading)
                            }
                        }
                    }
                }
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        Task {
                            try await reloadLists()
                        }
                    }
                }
                .onChange(of: maxCompletedAgeDaysSetting) {
                    Task {
                        try await reloadLists()
                    }
                }
                ZStack {
                    if listsLoadingTime >= 1 && listsLoading {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
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
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                        .transition(.blurReplace)
                    }
                }.animation(.snappy, value: listsLoading)
                
            }
            .onReceive(clock) { _ in
                withAnimation(.snappy) {
                    listsLoadingTime = listsLoading ? listsLoadingTime + 1 : 0
                }
            }
        }
        .task {
            guard model == nil else { return }
            model = await ViewModel(modelContext: modelContext)
        }
    }
    
    func reloadLists() async throws {
        guard model != nil else {
            throw RuntimeError(message: "no view model!")
        }
        
        listsLoading = true
        await model!.loadLists()
        listsLoading = false
    }
}

struct BethinkeryListView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true
    
    @Environment(\.editMode) private var editMode
    
    @FocusState private var addInFocus: Bool
    
    @State var model: ViewModel
    @State var list: BethinkeryList
    @State private var isAdding: Bool = false
    @State private var newTitle: String = ""
    @State private var shouldPresentEditListSheet = false
    
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
                    .sorted(by: { $0.ordinal <= $1.ordinal })
                    .filter({ model.showCompleted || !$0.isCompleted })
                
                ForEach(orderedBethinkeries) { bethinkery in
                    BethinkeryRowView(model: model, bethinkery: bethinkery)
                }
                .onMove { from, to in
                    model.moveBethinkery(from: from, to: to, list: list)
                }
                .onDelete { offsets in
                    // TODO: confirmation dialog
                    guard offsets.count == 1 else {
                        // impossible on iOS!
                        print("invalid number of offsets sent to delete item!")
                        return
                    }
                    model.delete(bethinkery: orderedBethinkeries[offsets.first!])
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
                    }
                    .sheet(isPresented: $shouldPresentEditListSheet, content: {
                        ListDetailView(model: model, list: list)
                    })
                    Button {
                        withAnimation {
                            isAdding = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(Color(hex: list.hexColor))
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
        let cleanTitle = newTitle.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }
        
        let newBethinkery = EditBethinkery(title: cleanTitle, isCompleted: false)
        model.create(from: newBethinkery, list: list)
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
    
    @FocusState private var editFocus: Bool
    
    @State var model: ViewModel
    @State var bethinkery: Bethinkery
    @State private var isEditing: Bool = false
    @State private var editedTitle: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                Image(systemName: "pencil.line")
                    .font(.title2)
                    .foregroundColor(.gray)
            } else {
                Button {
                    withAnimation {
                        model.toggleCompleted(bethinkery: bethinkery)
                    }
                } label: {
                    Image(systemName: bethinkery.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(bethinkery.isCompleted ? .green : .gray)
                }
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
                Text(bethinkery.title)
                    .strikethrough(bethinkery.isCompleted)
                    .foregroundColor(bethinkery.isCompleted ? .gray : .primary)
                    .onTapGesture {
                        editedTitle = bethinkery.title
                        isEditing = true
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
        var updater = EditBethinkery.fromBethinkery(bethinkery: bethinkery)
        updater.title = editedTitle
        model.update(bethinkery: bethinkery, with: updater)
        
        cancelEdit()
    }
}

struct ListDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true
    
    @Environment(\.dismiss) private var dismiss
    
    @State var model: ViewModel
    @State private var title: String = ""
    @State private var newTitle: String = ""
    @State private var newColor: Color = Color.accentColor
    @State private var newSourceId: String = ""
    
    var list: BethinkeryList?

    private var isNew: Bool { list == nil }
    
    private var selectedSource: EKSource? {
        model.availableSources.first(where: {
            $0.sourceIdentifier == newSourceId
        })
    }
    
    var body: some View {
        if !model.availableSources.isEmpty {
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
                            withAnimation{
                                if isNew {
                                    let creator = EditBethinkeryList(title: newTitle, hexColor: newColor.toHex())
                                    guard selectedSource != nil else {
                                        print("Tried to create a List on a nonexistent Source!")
                                        return
                                    }
                                    model.createList(from: creator, source: selectedSource!)
                                } else {
                                    var updater = EditBethinkeryList.fromBethinkeryList(bethinkeryList: list!)
                                    updater.title = newTitle
                                    updater.hexColor = newColor.toHex()
                                    model.update(bethinkeryList: list!, with: updater)
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
