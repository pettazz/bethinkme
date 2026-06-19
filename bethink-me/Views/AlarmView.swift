import SwiftUI


struct AlarmView: View {
    var relativeAlarm: AbsoluteTimeAlarm?
    var alarm: BethinkeryAlarm

    var dateFormatter: DateFormatter {
        let it = DateFormatter()
        it.timeStyle = .short
        it.dateStyle = .medium
        it.doesRelativeDateFormatting = true

        return it
    }

    var allDayFormatter: DateFormatter {
        let it = DateFormatter()
        it.timeStyle = .none
        it.dateStyle = .medium
        it.doesRelativeDateFormatting = true

        return it
    }

    var intervalFormatter: DateComponentsFormatter {
        let it = DateComponentsFormatter()
        it.allowedUnits = [.year, .month, .day, .hour, .minute]
        it.allowsFractionalUnits = false
        it.zeroFormattingBehavior = .dropAll
        it.unitsStyle = .short

        return it
    }

    var relativeDateFormatted: String {
        if relativeAlarm != nil {
            return relativeAlarm!.isAllDay
                ? allDayFormatter.string(from: relativeAlarm!.time)
                : dateFormatter.string(from: relativeAlarm!.time)
        } else {
            return "?"
        }
    }

    var body: some View {
        HStack {
            if let timeAlarm = alarm as? AbsoluteTimeAlarm {
                if timeAlarm.isAllDay {
                    Image(systemName: "calendar")
                        .font(.headline)
                        .accessibilityLabel(Text("All-day alarm"))
                    Text(allDayFormatter.string(from: timeAlarm.time))
                } else {
                    Image(systemName: "calendar.badge.clock")
                        .font(.headline)
                        .accessibilityLabel(Text("Exact time alarm"))
                    Text(dateFormatter.string(from: timeAlarm.time))
                }
            } else if let timeAlarm = alarm as? RelativeTimeAlarm {
                let relativity = timeAlarm.offset > 0 ? "after" : "before"

                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "alarm.fill")
                            .font(.headline)
                            .accessibilityLabel(Text("Relative time alarm"))
                        Text((intervalFormatter.string(from: abs(timeAlarm.offset)) ?? "unknown") +
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
            } else if let proxAlarm = alarm as? ProximityAlarm {
                Image(systemName: "location.circle.fill")
                    .font(.headline)
                    .accessibilityLabel(Text("Location alarm"))
                Text("\(proxAlarm.type.title) \(proxAlarm.title)")
            } else {
                Text("type: wat da fuk")
            }
        }
    }
}
