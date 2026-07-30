import SwiftUI


struct AlertDialogView: View {
    @Environment(\.colorScheme)
    var colorScheme

    let alertModel: AlertDialogModel

    var body: some View {
        // TODO: factor out a ton of this stuff
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                Text(alertModel.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(uiColor: .label))
                    .padding(.top, 30)

                Text(.init(alertModel.message))
                    .padding(.vertical, 10)
                    .fontWeight(.regular)
                    .foregroundStyle(Color(uiColor: .label))
                    .multilineTextAlignment(.leading)
            }
            .font(.body)
            .fontWeight(.regular)
            .foregroundStyle(.primary)
            .tint(.accentColor)
            .frame(maxWidth: .infinity)
            .presentationBackground(.clear)

            if let diffAlarms = alertModel.diffAlarms {
                ScrollView {
                    HStack(alignment: .top, spacing: 20) {
                        if let currentAlarms = alertModel.currentAlarms,
                           !currentAlarms.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Current")
                                    .font(.headline)
                                    .foregroundStyle(Color(uiColor: .label))
                                ForEach(currentAlarms.sortedAlarms, id: \.id) { alarm in
                                    AlarmView(relativeAlarm: currentAlarms.earliestAlarm, alarm: alarm)
                                        .fontWeight(.regular)
                                        .foregroundStyle(Color(uiColor: .label))
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("New")
                                .font(.headline)
                                .foregroundStyle(Color(uiColor: .label))
                            if diffAlarms.isEmpty {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Image(systemName: "calendar.badge.minus")
                                        .font(.headline)
                                        .accessibilityHidden(true)
                                        .frame(width: 24, alignment: .center)
                                    Text("Remove all alarms")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fontWeight(.regular)
                                }
                            } else {
                                ForEach(diffAlarms.sortedAlarms, id: \.id) { alarm in
                                    AlarmView(relativeAlarm: diffAlarms.earliestAlarm, alarm: alarm)
                                        .fontWeight(.regular)
                                }
                            }
                        }
                        .foregroundStyle(Color(uiColor: .label))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 400)
            }

            if let reminderList = alertModel.reminderList, !reminderList.isEmpty {
                ScrollView {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Reminders to be Deleted")
                                .font(.headline)
                                .foregroundStyle(Color(uiColor: .label))
                            ForEach(reminderList, id: \.id) { reminder in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.headline)
                                        .accessibilityHidden(true)
                                        .frame(width: 24, alignment: .center)
                                    Text(reminder.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fontWeight(.regular)
                                }
                            }
                        }
                        .foregroundStyle(Color(uiColor: .label))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 400)
            }

            if let dupes = alertModel.duplicateList, !dupes.isEmpty {
                ScrollView {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Reminders to be Deleted")
                                .font(.headline)
                                .foregroundStyle(Color(uiColor: .label))
                            ForEach(dupes.lists) { list in
                                Text(list.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fontWeight(.regular)

                                ForEach(list.groupedRows, id: \.id) { reminder in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Image(systemName: "circle")
                                            .font(.headline)
                                            .accessibilityHidden(true)
                                            .frame(width: 24, alignment: .center)
                                        Text(.init(reminder.count > 1 ?
                                                    "**\(reminder.count)x** \(reminder.title)" :
                                                    reminder.title))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .fontWeight(.regular)
                                    }
                                }
                            }
                        }
                        .foregroundStyle(Color(uiColor: .label))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 400)
            }

            VStack(alignment: .center) {
                ForEach(Array(alertModel.actions.enumerated()), id: \.offset) { _, action in
                    Button(role: action.role) {
                        action.action()
                        alertModel.dismiss()
                    } label: {
                        Text(action.title)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 5)
                }

                if alertModel.showDefaultCancel {
                    Button(role: .cancel) {
                        alertModel.dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .foregroundStyle(colorScheme == .dark ? .gray : .black)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 30)
                    .padding(.top, 15)
                    .padding(.bottom, 10)

                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 25)
        .padding(.top, 25)
        .presentationBackground(.ultraThinMaterial)
    }
}

#Preview {
    let model = AlertDialogModel()
    model.isPresenting = true
    model.title = "Moving Reminder"
    // swiftlint:disable:next line_length
    model.message = "This Reminder has alarms and is being moved to a List with different alarms. Do you want to discard the existing alarms and replace them with the alarms from the new list?"
    model.actions = [
        ActionButton(title: "Click me", role: .destructive, action: { print("ok") }),
        ActionButton(title: "Do not click me", action: { print("no!") })
    ]
    model.showDefaultCancel = true
    model.diffAlarms = [
        AbsoluteTimeAlarmTemplate(id: "123", time: Date.now.addingTimeInterval(-1000), isAllDay: false),
        AbsoluteTimeAlarmTemplate(id: "234", time: Date.now.addingTimeInterval(278934), isAllDay: true)
    ]
    return AlertDialogView(alertModel: model)
}
