import EventKit
import SwiftUI


struct ListDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true

    @Environment(\.dismiss)
    private var dismiss

    @State private var title: String = ""
    @State private var newTitle: String = ""
    @State private var newColor: Color = Color.accentColor
    @State private var newSourceId: String = ""

    var sharedModel: SharedViewModel
    var listModel: ListViewModel
    var list: BethinkeryList?

    private var isNew: Bool { list == nil }

    private var selectedSource: EKSource? {
        listModel.availableSources.first(where: { $0.sourceIdentifier == newSourceId })
    }

    var body: some View {
        if !listModel.availableSources.isEmpty {
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
                                    ForEach(listModel.availableSources, id: \.sourceIdentifier) { source in
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
                                        try listModel.create(from: creator, source: selectedSource!)
                                    } else {
                                        var updater = EditBethinkeryList.fromBethinkeryList(list!)
                                        updater.title = newTitle
                                        updater.hexColor = newColor.toHex()
                                        try listModel.update(list!, with: updater)
                                    }
                                    dismiss()
                                }
                            }
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
                    newSourceId = listModel.defaultSource?.sourceIdentifier ??
                    listModel.availableSources.first?.sourceIdentifier ??
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
