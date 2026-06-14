// swiftlint:disable type_contents_order
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

    @State private var listsLoading: Bool = false
    @State private var listsLoadingTime: Int = 0
    @State private var showDelayedSpinner = false

    @State private var selectedBethinkeryForEdit: Bethinkery?

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
            if scenePhase == .active {
                await tryTask(Task { try await reloadLists() })
            }
        }
        .sheet(item: $selectedBethinkeryForEdit) { bethinkery in
            if let model {
                BethinkeryDetailView(
                    model: model,
                    bethinkery: bethinkery
                )
                .id(bethinkery.id)
            }
        }
    }

    func reloadLists() async throws {
        listsLoading = true

        if model == nil {
            model = await ViewModel(modelContext: modelContext)
        }
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

    var model: ViewModel
    var list: BethinkeryList
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

    var model: ViewModel
    var bethinkery: Bethinkery
    @State private var isEditing: Bool = false
    @State private var editedTitle: String = ""

    var body: some View {
        VStack(alignment: .trailing) {
            HStack {
                Group {
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
                }
                .containerRelativeFrame(.horizontal, count: 10, span: 1, spacing: 5, alignment: .leading)

                Group {
                    if isEditing {
                        TextField(bethinkery.title, text: $editedTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .strikethrough(bethinkery.isCompleted)
                            .foregroundColor(bethinkery.isCompleted ? .gray : .primary)
                            .onTapGesture {
                                editedTitle = bethinkery.title

                                withAnimation(.snappy) {
                                    isEditing = true
                                }
                            }
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 5, alignment: .trailing)
            }


            if !bethinkery.isCompleted && !isEditing {
                if (displayNotes && bethinkery.hasNotes) || displayURLs && bethinkery.hasUrl {
                    HStack {
                        VStack {
                            if displayNotes && bethinkery.hasNotes {
                                Text(bethinkery.notes!)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if displayURLs && bethinkery.hasUrl {
                                Link(bethinkery.url!.absoluteString, destination: bethinkery.url!)
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 5, alignment: .trailing)
                        .padding(.top, 1)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: isEditing)
    }

    private func cancelEdit() {
        editedTitle = ""
        withAnimation {
            isEditing = false
        }
    }

    private func saveEdit() {
        withErrorReporter {
            let updater = EditBethinkery.fromBethinkery(bethinkery)
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

    var model: ViewModel
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

    var model: ViewModel
    var bethinkery: Bethinkery

    @StateObject private var editBethinkeryCommand: EditBethinkery = EditBethinkery()

    @State private var dueDateEditorVisible: Bool = false

    @State private var newAlarmFormVisible: Bool = false
    @State private var newAlarmType: AvailableAlarmTypes = .timeAlarm
    @State private var newAlarmTime: Date?
    @State private var newAlarmTitle: String?
    @State private var newAlarmRadius: Double?
    @State private var newAlarmLocation: LatLng?
    @State private var newAlarmProxType: AlarmProximityType = .nothing
    @State private var dueDatePickerValue: Date = .now

    init(model: ViewModel, bethinkery: Bethinkery) {
        self.model = model
        self.bethinkery = bethinkery
        _editBethinkeryCommand = StateObject(wrappedValue: .fromBethinkery(bethinkery))
        _dueDatePickerValue = State(initialValue: bethinkery.dueDate ?? .now)
    }

    private var dueDateEnabled: Binding<Bool> {
        Binding(
            get: { editBethinkeryCommand.dueDate != nil },
            set: { enabled in
                if enabled {
                    editBethinkeryCommand.dueDate = dueDatePickerValue
                } else {
                    editBethinkeryCommand.dueDate = nil
                }
            }
        )
    }

    var dateFormatter: DateFormatter {
        let it = DateFormatter()
        it.dateFormat = "MMM d"
        it.dateStyle = .medium
        it.doesRelativeDateFormatting = true

        return it
    }

    var body: some View {
        NavigationStack {
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
                            prompt: Text("Title"))
                        .autocorrectionDisabled(!enableAutocorrectSetting)

                        TextField(
                            "Notes",
                            text: $editBethinkeryCommand.notesText,
                            prompt: Text("Notes"),
                            axis: .vertical)

                        TextField(
                            "URL",
                            text: $editBethinkeryCommand.urlText,
                            prompt: Text("URL"))
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                    }

                    Section {
                        Toggle(isOn: dueDateEnabled) {
                            Group {
                                Text("Due Date").bold()
                                if dueDateEnabled.wrappedValue && editBethinkeryCommand.dueDate != nil {
                                    Text(dateFormatter.string(from: editBethinkeryCommand.dueDate!))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    dueDateEditorVisible.toggle()
                                }
                            }
                            .accessibilityAddTraits(.isButton)
                        }
                        .onChange(of: dueDateEnabled.wrappedValue, {
                            withAnimation {
                                dueDateEditorVisible = dueDateEnabled.wrappedValue
                            }
                        })

                        if dueDateEnabled.wrappedValue && dueDateEditorVisible {
                            DatePicker("Select Due Date",
                                       selection: $dueDatePickerValue,
                                       displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .onChange(of: dueDatePickerValue) {
                                    editBethinkeryCommand.dueDate = dueDatePickerValue
                                }
                        }
                    }

                    Section {
                        if bethinkery.hasAlarms {
                            ForEach(bethinkery.alarms) { alarm in
                                BethinkeryAlarmView(alarm: alarm)
                            }
                        }

                        if newAlarmFormVisible {
                            Picker("Type", selection: $newAlarmType) {
                                ForEach(AvailableAlarmTypes.allCases, id: \.self) { alarmType in
                                    Text(alarmType.rawValue).tag(alarmType)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Button(newAlarmFormVisible ? "Cancel" : "Add Alarm") {
                            withAnimation {
                                newAlarmFormVisible.toggle()
                            }
                        }
                    } header: {
                        Text("Alarms")
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

struct BethinkeryAlarmView: View {
    var alarm: BethinkeryAlarm

    var body: some View {
        VStack(alignment: .leading) {
            Text("id: \(alarm.id)")
            if let timeAlarm = alarm as? BethinkeryTimeAlarm {
                Text("type: time")
                Text("trigger: \(timeAlarm.time.ISO8601Format())")
            } else if let proxAlarm = alarm as? BethinkeryProximityAlarm {
                Text("type: prox")
                Text("trigger: \(proxAlarm.title)")
            } else {
                Text("type: wat da fuk")
            }
        }

    }
}
