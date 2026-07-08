import SwiftUI


struct RowView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true
    @AppStorage(SettingsKey.displayNotes.rawValue)
    private var displayNotes: Bool = false
    @AppStorage(SettingsKey.displayURLs.rawValue)
    private var displayURLs: Bool = false
    @AppStorage(SettingsKey.displayAlarmIcons.rawValue)
    private var displayAlarmIcons: Bool = false

    @FocusState private var editFocus: Bool
    @State private var isEditing: Bool = false
    @State private var editedTitle: String = ""

    var bethinkeryModel: BethinkeryViewModel
    var bethinkery: Bethinkery

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
                                    try bethinkeryModel.toggleCompleted(bethinkery)
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
                            if displayNotes, let notes = bethinkery.notes {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if displayURLs, let url = bethinkery.url {
                                Link(url.absoluteString, destination: url)
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 5, alignment: .trailing)
                    }
                }
                if displayAlarmIcons {
                    HStack {
                        if bethinkery.hasAbsoluteTimeAlarm {
                            Image(systemName: "calendar")
                                .accessibilityLabel(Text("Has at least one absolute time alarm set"))
                                .foregroundColor(Color(hex: bethinkery.list.hexColor))
                        }
                        if bethinkery.hasRelativeTimeAlarm {
                            Image(systemName: "alarm.fill")
                                .accessibilityLabel(Text("Has at least one relative time alarm set"))
                                .foregroundColor(Color(hex: bethinkery.list.hexColor))
                        }
                        if bethinkery.hasProximityAlarm {
                            Image(systemName: "location.circle.fill")
                                .accessibilityLabel(Text("Has at least one location alarm set"))
                                .foregroundColor(Color(hex: bethinkery.list.hexColor))
                        }
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
            try bethinkeryModel.update(bethinkery, with: updater)
        }

        cancelEdit()
    }
}
