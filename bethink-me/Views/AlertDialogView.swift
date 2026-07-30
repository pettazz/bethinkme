import SwiftUI


struct AlertDialogView: View {
    @Environment(\.colorScheme)
    var colorScheme

    let alertModel: AlertDialogModel

    var body: some View {
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
            .foregroundStyle(Color(uiColor: .label))
            .tint(.accentColor)
            .frame(maxWidth: .infinity)
            .presentationBackground(.clear)

            alarmDiff
            reminderList
            dupeList
            actionList
        }
        .padding(.horizontal, 25)
        .padding(.top, 25)
        .presentationBackground(.ultraThinMaterial)
    }

    @ViewBuilder private var alarmDiff: some View {
        if let diffAlarms = alertModel.diffAlarms {
            scrollableList {
                HStack(alignment: .top, spacing: 20) {
                    if let current = alertModel.currentAlarms, !current.isEmpty {
                        alarmColumn(title: "Current", alarms: current)
                    }
                    newAlarmsColumn(diffAlarms)
                }
            }
        }
    }

    @ViewBuilder private var reminderList: some View {
        if let reminders = alertModel.reminderList, !reminders.isEmpty {
            scrollableList {
                groupedPanel(title: "Reminders to be Deleted") {
                    ForEach(reminders, id: \.id) { reminder in
                        iconRow(name: reminder.isCompleted ? "checkmark.circle.fill" : "circle", text: reminder.title)
                    }
                }
            }
        }
    }

    @ViewBuilder private var dupeList: some View {
        if let dupes = alertModel.duplicateList, !dupes.isEmpty {
            scrollableList {
                groupedPanel(title: "Reminders to be Deleted") {
                    ForEach(dupes.lists) { list in
                        Text(list.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fontWeight(.regular)

                        ForEach(list.groupedRows, id: \.id) { reminder in
                            iconRow(name: "circle",
                                    text: reminder.count > 1 ?
                                        "**\(reminder.count)x** \(reminder.title)" :
                                        reminder.title)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var actionList: some View {
        VStack(alignment: .center) {
            ForEach(Array(alertModel.actions.enumerated()), id: \.offset) { _, action in
                alertButton(action.title, role: action.role) {
                    action.action()
                    alertModel.dismiss()
                }
            }

            if alertModel.showDefaultCancel {
                alertButton("Cancel",
                            role: .cancel,
                            foreground: colorScheme == .dark ? .gray : .black,
                            verticalPadding: (top: 15, bottom: 10)) {
                    alertModel.dismiss()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func scrollableList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: 400)
    }

    @ViewBuilder
    private func groupedPanel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(uiColor: .label))
            content()
        }
        .groupedPanelStyle()
    }

    @ViewBuilder
    private func iconRow(name: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: name)
                .font(.headline)
                .accessibilityHidden(true)
                .frame(width: 24, alignment: .center)
            Text(.init(text))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fontWeight(.regular)
        }
    }

    @ViewBuilder
    private func alarmColumn(title: String, alarms: [BethinkeryAlarmTemplate]) -> some View {
        groupedPanel(title: title) {
            ForEach(alarms.sortedAlarms, id: \.id) { alarm in
                AlarmView(relativeAlarm: alarms.earliestAlarm, alarm: alarm)
                    .fontWeight(.regular)
            }
        }
    }

    @ViewBuilder
    private func newAlarmsColumn(_ diffAlarms: [BethinkeryAlarmTemplate]) -> some View {
        groupedPanel(title: "New") {
            if diffAlarms.isEmpty {
                iconRow(name: "calendar.badge.minus", text: "Remove all alarms")
            } else {
                ForEach(diffAlarms.sortedAlarms, id: \.id) { alarm in
                    AlarmView(relativeAlarm: diffAlarms.earliestAlarm, alarm: alarm)
                        .fontWeight(.regular)
                }
            }
        }
    }

    @ViewBuilder
    private func alertButton(_ title: String,
                             role: ButtonRole? = nil,
                             foreground: Color? = nil,
                             verticalPadding: (top: CGFloat, bottom: CGFloat) = (5, 5),
                             action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            if let foreground {
                Text(title)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .foregroundStyle(foreground)
            } else {
                Text(title)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 30)
        .padding(.top, verticalPadding.top)
        .padding(.bottom, verticalPadding.bottom)
    }
}

struct GroupedPanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color(uiColor: .label))
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

extension View {
    func groupedPanelStyle() -> some View {
        modifier(GroupedPanelStyle())
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
