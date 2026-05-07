import SwiftUI

struct MainView: View {
    @State private var model: ViewModel = ViewModel()
    @State private var path = NavigationPath()
    
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
                            BethinkeryListView(model: model, list: $list)
                        }
                        .onDelete { offsets in
                            // TODO: confirmation dialog?
                            model.delete(offsets: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Lists")
            .task {
                await model.loadLists()
            }
        }
    }
}

struct BethinkeryListView: View {
    @Bindable var model: ViewModel
    @Binding var list: BethinkeryList
    @State private var isAdding: Bool = false
    
    var body: some View {
        Section(content: {
            ForEach($model.bethinkeries.filter({
                $0.wrappedValue.list == list.id
            })) { $bethinkery in
                BethinkeryRow(model: model, bethinkery: $bethinkery)
            }
            if isAdding {
                AddingBethinkeryRow(model: model, list: $list, isVisible: $isAdding)
            }
            
        }, header: {
            HStack {
                Text(list.title).font(.title2)
                Spacer()
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        })
    }
}

struct BethinkeryRow: View {
    @Bindable var model: ViewModel
    @Binding var bethinkery: Bethinkery
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    model.toggleComplete(for: &bethinkery)
                }
            } label: {
                Image(systemName: bethinkery.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(bethinkery.isCompleted ? .green : .gray)
            }
            
            Text(bethinkery.title)
                .strikethrough(bethinkery.isCompleted)
                .foregroundColor(bethinkery.isCompleted ? .gray : .primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
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
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        saveNew(andClose: true)
                    }
                }
            }
            .submitLabel(.next)
            .onSubmit {
                saveNew()
            }
    }
    
    private func saveNew(andClose: Bool = false) {
        let newTitle = newBethinkery.trimmingCharacters(in: .whitespaces)
        if (!newTitle.isEmpty) {
            model.create(title: newTitle, list: list)
            self.newBethinkery = ""
        }
        
        if (andClose) {
            self.addInFocus = false
            self.isVisible = false
        } else {
            self.addInFocus = true
        }
    }
}

#Preview {
    MainView()
}
