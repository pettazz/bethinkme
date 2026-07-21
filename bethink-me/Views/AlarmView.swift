import SwiftUI


struct AlarmView: View {
    private static let dateFormatter: DateFormatter = {
        let it = DateFormatter()
        it.timeStyle = .short
        it.dateStyle = .medium
        it.doesRelativeDateFormatting = true

        return it
    }()

    private static let allDayFormatter: DateFormatter = {
        let it = DateFormatter()
        it.timeStyle = .none
        it.dateStyle = .medium
        it.doesRelativeDateFormatting = true

        return it
    }()

    private static let intervalFormatter: DateComponentsFormatter = {
        let it = DateComponentsFormatter()
        it.allowedUnits = [.year, .month, .day, .hour, .minute]
        it.allowsFractionalUnits = false
        it.zeroFormattingBehavior = .dropAll
        it.unitsStyle = .short

        return it
    }()

    var relativeAlarm: AbsoluteTimeAlarmTemplate?
    var alarm: any BethinkeryAlarmTemplate

    var relativeDateFormatted: String {
        if let relativeAlarm {
            return relativeAlarm.isAllDay
                ? AlarmView.allDayFormatter.string(from: relativeAlarm.time)
                : AlarmView.dateFormatter.string(from: relativeAlarm.time)
        } else {
            return "?"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let timeAlarm = alarm as? AbsoluteTimeAlarmTemplate {
                if timeAlarm.isAllDay {
                    Image(systemName: "calendar")
                        .font(.headline)
                        .accessibilityLabel(Text("All-day alarm"))
                        .frame(width: 24, alignment: .center)
                    Text(AlarmView.allDayFormatter.string(from: timeAlarm.time))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Image(systemName: "calendar.badge.clock")
                        .font(.headline)
                        .accessibilityLabel(Text("Exact time alarm"))
                        .frame(width: 24, alignment: .center)
                    Text(AlarmView.dateFormatter.string(from: timeAlarm.time))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let timeAlarm = alarm as? RelativeTimeAlarmTemplate {
                let relativity = timeAlarm.offset > 0 ? "after" : "before"

                Image(systemName: "alarm.fill")
                    .font(.headline)
                    .accessibilityLabel(Text("Relative time alarm"))
                    .frame(width: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text((AlarmView.intervalFormatter.string(from: abs(timeAlarm.offset)) ?? "unknown") +
                         " \(relativity) \(relativeDateFormatted)")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if relativeAlarm == nil {
                        Text("Missing exact time alarm")
                            .foregroundStyle(Color.red)
                    }
                }
            } else if let proxAlarm = alarm as? ProximityAlarmTemplate {
                Image(systemName: "location.circle.fill")
                    .font(.headline)
                    .accessibilityLabel(Text("Location alarm"))
                    .frame(width: 24, alignment: .center)
                Text("\(proxAlarm.proximityType.title) \(proxAlarm.title)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
