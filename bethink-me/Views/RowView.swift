import SwiftUI


struct RowView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = kEnableAutocorrectDefault
    @AppStorage(SettingsKey.displayNotes.rawValue)
    private var displayNotes: Bool = kDisplayNotesDefault
    @AppStorage(SettingsKey.displayURLs.rawValue)
    private var displayURLs: Bool = kDisplayURLsDefault
    @AppStorage(SettingsKey.displayAlarmIcons.rawValue)
    private var displayAlarmIcons: Bool = kDisplayAlarmIconsDefault

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
                        RepeatableTextField(text: $editedTitle,
                                            enableAutocorrect: enableAutocorrectSetting,
                                            returnKey: .default,
                                            onSubmit: saveEdit,
                                            onDone: saveEdit)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focused($editFocus)
                            .onAppear {
                                editFocus = true
                            }
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") {
                                        closeEdit()
                                    }
                                }
                            }
                            .onChange(of: editFocus) {
                                if isEditing && !editFocus {
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

                                withAnimation(.snappy(duration: 0.25)) {
                                    isEditing = true
                                }
                            }
                            .accessibilityAddTraits(.isButton)
                            .padding(.trailing, displayAlarmIcons ? 40 : 0)
                            .overlay(alignment: .topTrailing) {
                                if displayAlarmIcons {
                                    alarmIconStack()
                                }
                            }
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
            }
        }
        .sensoryFeedback(.selection, trigger: isEditing)
    }

    @ViewBuilder
    private func alarmIconStack() -> some View {
        HStack(spacing: -10) {
            if bethinkery.hasAbsoluteTimeAlarm {
                stackedAlarmIcon(name: "calendar",
                                 color: bethinkery.list.hexColor,
                                 label: "Has at least one absolute time alarm set")
            }
            if bethinkery.hasRelativeTimeAlarm {
                stackedAlarmIcon(name: "alarm.fill",
                                 color: bethinkery.list.hexColor,
                                 label: "Has at least one relative time alarm set")
            }
            if bethinkery.hasProximityAlarm {
                stackedAlarmIcon(name: "location.circle.fill",
                                 color: bethinkery.list.hexColor,
                                 label: "Has at least one location alarm set")
            }
        }
        .font(.footnote)
        .fixedSize()
    }

    @ViewBuilder
    private func stackedAlarmIcon(name: String, color: String, label: String) -> some View {
        Image(systemName: name)
            .foregroundColor(Color(hex: color))
            .padding(4)
            .background(Circle().fill(Color(.systemBackground)))
            .overlay(Circle().stroke(Color(.separator).opacity(0.75), lineWidth: 1))
            .accessibilityLabel(Text(label))
    }

    private func closeEdit() {
        editedTitle = ""
        editFocus = false
        withAnimation(.snappy(duration: 0.25)) {
            isEditing = false
        }
    }

    private func saveEdit() {
        let cleanTitle = editedTitle.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }
        
        withErrorReporter {
            let updater = EditBethinkery.fromBethinkery(bethinkery)
            updater.title = cleanTitle
            try bethinkeryModel.update(bethinkery, with: updater)
        }

        closeEdit()
    }
}
