import SwiftUI


struct RowView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = kEnableAutocorrectDefault
    @AppStorage(SettingsKey.enableFullRangePriority.rawValue)
    private var enableFullRangePriority: Bool = kEnableFullRangePriorityDefault
    @AppStorage(SettingsKey.displayNotes.rawValue)
    private var displayNotes: Bool = kDisplayNotesDefault
    @AppStorage(SettingsKey.displayPriority.rawValue)
    private var displayPriority: Bool = kDisplayPriorityDefault
    @AppStorage(SettingsKey.displayDueDate.rawValue)
    private var displayDueDate: Bool = kDisplayDueDateDefault
    @AppStorage(SettingsKey.displayAlarmIcons.rawValue)
    private var displayAlarmIcons: Bool = kDisplayAlarmIconsDefault

    @State private var editFocus: Bool = false
    @State private var isEditing: Bool = false
    @State private var editedTitle: String = ""

    var bethinkeryModel: BethinkeryViewModel
    var bethinkery: Bethinkery

    var flashKind: RowFlashKind?

    var body: some View {
        VStack(alignment: .trailing) {
            HStack {
                Group {
                    if flashKind == .deduped {
                        Image(systemName: "circle")
                            .font(.title2)
                            .hidden()
                            .overlay {
                                Image(systemName: "circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: bethinkery.list.hexColor))
                                Image(systemName: "rectangle.on.rectangle.dashed")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(7)
                                    .foregroundStyle(Color(hex: bethinkery.list.hexColor).contrastingForeground)
                                    .accessibilityHidden(true)
                            }
                            .accessibilityHidden(true)
                    } else if flashKind == .created {
                        Image(systemName: "circle")
                            .font(.title2)
                            .hidden()
                            .overlay {
                                Image(systemName: "circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: bethinkery.list.hexColor))
                                Image(systemName: "plus")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(6)
                                    .foregroundStyle(Color(hex: bethinkery.list.hexColor).contrastingForeground)
                                    .accessibilityHidden(true)
                            }
                            .accessibilityHidden(true)
                    } else if isEditing {
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
                                            isFocused: $editFocus,
                                            enableAutocorrect: enableAutocorrectSetting,
                                            returnKey: .default,
                                            onSubmit: {
                                                if isEditing {
                                                    saveEdit()
                                                }
                                            },
                                            onDone: {
                                                if isEditing {
                                                    saveEdit()
                                                }
                                            },
                                            onCancel: {
                                                if isEditing {
                                                    closeEdit()
                                                }
                                            },
                                            onEndEditing: {
                                                if isEditing {
                                                    saveEdit()
                                                }
                                            })
                            .frame(maxWidth: .infinity, alignment: .leading)

                    } else {
                        HStack {
                            if displayPriority && bethinkery.hasPriority,
                               let priority = BethinkeryPriority(rawValue: bethinkery.priority),
                               let icon = enableFullRangePriority ? priority.icon : priority.shortRangeIcon {
                                let title = enableFullRangePriority ? priority.title : priority.shortRangeTitle
                                Image(systemName: icon)
                                    .font(enableFullRangePriority ? .headline : .footnote)
                                    .bold()
                                    .foregroundColor(Color(hex: bethinkery.list.hexColor))
                                    .accessibilityLabel(Text("\(title) priority"))
                            }
                            Text(bethinkery.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .strikethrough(bethinkery.isCompleted)
                                .foregroundColor(bethinkery.isCompleted ? .gray : .primary)
                                .onTapGesture {
                                    editedTitle = bethinkery.title
                                    editFocus = true

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
                }
                .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 5, alignment: .trailing)
            }


            if !bethinkery.isCompleted && !isEditing {
                if (displayNotes && bethinkery.hasNotes) || (displayDueDate && bethinkery.impliedDueDate != nil) {
                    VStack {
                        if displayNotes, let notes = bethinkery.notes {
                            Text(notes)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if displayDueDate, let dueDate = bethinkery.impliedDueDate {
                            let color: Color = dueDate < Date() ? .red : .primary
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.caption)
                                    .foregroundColor(color)
                                    .accessibilityHidden(true)
                                Text(Formatters.dateFormatter.string(from: dueDate))
                                    .font(.caption)
                                    .foregroundColor(color)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 5, alignment: .trailing)
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
        guard !cleanTitle.isEmpty else {
            closeEdit()
            return
        }

        let success = withErrorReporter {
            let updater = EditBethinkery.fromBethinkery(bethinkery)
            updater.title = cleanTitle
            try bethinkeryModel.update(bethinkery, with: updater)
            return true
        } ?? false

        if success {
            closeEdit()
        } else {
            editFocus = true
        }
    }
}
