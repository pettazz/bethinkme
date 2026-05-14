import SwiftData
import SwiftUI

enum Route: Hashable {
    case newList
    case editList(list: BethinkeryList)
}

struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var model: ViewModel = ViewModel()
    @State private var path = NavigationPath()
    @State private var showCompleted: Bool = false
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                if (!model.hasAccess) {
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
                } else if (model.bethinkeryLists.isEmpty) {
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
                        ForEach($model.bethinkeryLists) { $list in
                            BethinkeryListView(model: model, list: $list, navPath: $path)
                        }
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        path.append(Route.newList)
                    } label: {
                        Image(systemName: "text.pad.header.badge.plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showCompleted.toggle()
                        Task {
                            await model.loadLists(includeCompleted: showCompleted)
                        }
                    } label: {
                        if showCompleted {
                            Image(systemName: "eye.slash.fill")
                            Text("Hide completed")
                        } else {
                            Image(systemName: "eye.fill")
                            Text("Show completed")
                        }
                    }
                }
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    Task {
                        await model.loadLists(includeCompleted: showCompleted)
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .editList(let list):
                    ListDetail(model: model, list: list)
                case .newList:
                    ListDetail(model: model)
                }
                
            }
        }
    }
}

struct BethinkeryListView: View {
    @Bindable var model: ViewModel
    @Binding var list: BethinkeryList
    @Binding var navPath: NavigationPath
    @State private var isAdding: Bool = false
    
    var body: some View {
        Section(content: {
            if isAdding {
                AddingBethinkeryRow(model: model, list: $list, isVisible: $isAdding)
            }
            ForEach($list.bethinkeries) { $bethinkery in
                BethinkeryRow(model: model, bethinkery: $bethinkery)
            }
            .onDelete { offsets in
                // TODO: confirmation dialog? ensure multiselect isnt possible?
                model.delete(offsets: offsets, from: list.id)
            }
            
        }, header: {
            HStack {
                Text(list.title)
                    .font(.headline)
                    .foregroundColor(list.color)
                Spacer()
                Button {
                    navPath.append(Route.editList(list: list))
                } label: {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(list.color)
                }
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(list.color)
                }
            }
        })
    }
}

struct BethinkeryRow: View {
    @Bindable var model: ViewModel
    @Binding var bethinkery: Bethinkery
    @FocusState private var editFocus: Bool
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
                        bethinkery.isCompleted.toggle()
                        model.update(bethinkery: bethinkery)
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
                        DispatchQueue.main.async() {
                          self.editFocus = true
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .keyboard) {
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
        bethinkery.title = editedTitle
        model.update(bethinkery: bethinkery)
        
        cancelEdit()
    }
}

struct AddingBethinkeryRow: View {
    @Bindable var model: ViewModel
    @Binding var list: BethinkeryList
    @Binding var isVisible: Bool
    @FocusState private var addInFocus: Bool
    @State private var newBethinkery: String = ""
    
    var body: some View {
        TextField("", text: $newBethinkery)
            .textFieldStyle(.plain)
            .focused($addInFocus)
            .onAppear {
                DispatchQueue.main.async() {
                  self.addInFocus = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Cancel") {
                        close()
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    Spacer()
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        saveNew()
                        close()
                    }
                }
            }
            .submitLabel(.next)
            .onSubmit {
                saveNew()
            }
            .onChange(of: addInFocus) {
                if !addInFocus {
                    close()
                }
            }
            
    }
    
    private func saveNew() {
        let newTitle = newBethinkery.trimmingCharacters(in: .whitespaces)
        guard !newTitle.isEmpty else { return }
        
        model.create(title: newTitle, listId: list.id)
        
        self.newBethinkery = ""
        self.addInFocus = true
    }
    
    private func close() {
        self.newBethinkery = ""
        self.addInFocus = false
        self.isVisible = false
    }
}

struct ListDetail: View {
    @Bindable var model: ViewModel
    var list: BethinkeryList?
    
    var body: some View {
//        let isNew = list == nil;
//        
//        var title: String = list.title ?? ""
//        
//        VStack {
//            Form {
//                Section(header: Text("Details")) {
//                    TextField(text: $title, label: { Text("Name") })
//                }
//            }
//        }
//        .navigationTitle(isNew ? "New List" : list!.title)
//        .toolbar {
//            ToolbarItem(placement: .primaryAction) {
//                Button("Save") {
//                    //
//                }
//            }
//        }
    }
}
