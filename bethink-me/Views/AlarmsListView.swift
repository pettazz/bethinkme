import SwiftUI


struct AlarmsListView: View {
    @Binding var alarmList: [any BethinkeryAlarmTemplate]

    var body: some View {
        Section {
            if !alarmList.isEmpty {
                ForEach(alarmList.sortedAlarms, id: \.id) { alarm in
                    AlarmView(relativeAlarm: alarmList.earliestAlarm, alarm: alarm)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                alarmList.removeAll(where: { $0.id == alarm.id })
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        } header: {
            Text("Alarms")
        }
    }
}
