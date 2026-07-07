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
        if relativeAlarm != nil {
            return relativeAlarm!.isAllDay
                ? AlarmView.allDayFormatter.string(from: relativeAlarm!.time)
                : AlarmView.dateFormatter.string(from: relativeAlarm!.time)
        } else {
            return "?"
        }
    }

    var body: some View {
        HStack {
            if let timeAlarm = alarm as? AbsoluteTimeAlarmTemplate {
                if timeAlarm.isAllDay {
                    Image(systemName: "calendar")
                        .font(.headline)
                        .accessibilityLabel(Text("All-day alarm"))
                    Text(AlarmView.allDayFormatter.string(from: timeAlarm.time))
                } else {
                    Image(systemName: "calendar.badge.clock")
                        .font(.headline)
                        .accessibilityLabel(Text("Exact time alarm"))
                    Text(AlarmView.dateFormatter.string(from: timeAlarm.time))
                }
            } else if let timeAlarm = alarm as? RelativeTimeAlarmTemplate {
                let relativity = timeAlarm.offset > 0 ? "after" : "before"

                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "alarm.fill")
                            .font(.headline)
                            .accessibilityLabel(Text("Relative time alarm"))
                        Text((AlarmView.intervalFormatter.string(from: abs(timeAlarm.offset)) ?? "unknown") +
                             " \(relativity) \(relativeDateFormatted)"
                        )
                    }

                    if relativeAlarm == nil {
                        HStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .foregroundStyle(Color.red)
                                .accessibilityHidden(true)
                            Text("Set an exact time alarm!")
                                .foregroundStyle(Color.red)
                        }
                    }
                }
            } else if let proxAlarm = alarm as? ProximityAlarmTemplate {
                Image(systemName: "location.circle.fill")
                    .font(.headline)
                    .accessibilityLabel(Text("Location alarm"))
                Text("\(proxAlarm.proximityType.title) \(proxAlarm.title)")
            }
        }
    }
}
