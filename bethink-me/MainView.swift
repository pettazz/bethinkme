import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var model: ViewModel?
    @State private var listEditMode: EditMode = .inactive
    
    var body: some View {
        NavigationStack {
            VStack {
                if model == nil {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(2.0, anchor: .center)
                } else {
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
//                                path.append(Route.newList)
                            } label: {
                                Image(systemName: "rectangle.stack.fill.badge.plus")
                            }
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
                                    // Text("Hide completed")
                                } else {
                                    Image(systemName: "eye.fill")
                                    // Text("Show completed")
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    Task {
                        guard model != nil else {
                            throw RuntimeError(message: "no view model!")
                        }
                        await model!.loadLists()
                    }
                }
            }
        }
        .task {
            guard model == nil else { return }
            model = await ViewModel(modelContext: modelContext)
        }
    }
}

struct BethinkeryListView: View {
    @Environment(\.editMode) private var editMode
    
    @FocusState private var addInFocus: Bool
    
    @State var model: ViewModel
    @State var list: BethinkeryList
    @State private var isAdding: Bool = false
    @State private var newTitle: String = ""
    
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
                    BethinkeryRow(model: model, bethinkery: bethinkery)
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
//                        navPath.append(Route.editList(list: list))
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.title)
                            .foregroundColor(Color(hex: list.hexColor))
                    }
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
        
        model.create(title: cleanTitle, list: list)
        newTitle = ""
        addInFocus = true
    }
    
    private func closeAdding() {
        newTitle = ""
        isAdding = false
        addInFocus = false
    }
}

struct BethinkeryRow: View {
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
                        model.update(bethinkery: bethinkery, title: nil, isCompleted: !bethinkery.isCompleted)
                    }
                } label: {
                    Image(systemName: bethinkery.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(bethinkery.isCompleted ? .green : .gray)
                }
            }
            
            if isEditing {
                TextField(bethinkery.title, text: $editedTitle)
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
        model.update(bethinkery: bethinkery, title: editedTitle, isCompleted: nil)
        
        cancelEdit()
    }
}

struct ListDetail: View {
    @State var model: ViewModel?
    var list: BethinkeryList?
    
    var body: some View {
        let isNew = list == nil;
                
        VStack {
            Form {
                Section {
//                    TextField(text: $title, label: { Text("Name") })
                }
            }
        }
        .navigationTitle(isNew ? "New List" : list!.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    //
                }
            }
        }
    }
}
