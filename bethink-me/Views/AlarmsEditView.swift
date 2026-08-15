import SwiftUI


struct AlarmsEditView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State private var newAlarmType: BethinkeryAlarmKind = .absoluteTimeAlarm

    @State private var newAlarmTime: Date = Date.now
    @State private var newAlarmIsAllDay: Bool = false

    @State private var newAlarmOffsetAmount: TimeInterval = 1
    @State private var newAlarmOffsetUnit: TimeAlarmIntervalUnits = .days
    @State private var newAlarmOffsetDirection: TimeAlarmIntervalDirection = .before

    @State private var newAlarmTitle: String?
    @State private var newAlarmAddress: String?
    @State private var newAlarmRadius: Double?
    @State private var newAlarmLocationLat: Double?
    @State private var newAlarmLocationLng: Double?
    @State private var newAlarmProxType: AlarmProximityType = .enter

    @Binding var alarmList: [any BethinkeryAlarmTemplate]
    var color: Color = .accentColor

    private var saveDisabled: Bool {
        newAlarmType == .proximityAlarm &&
            (newAlarmTitle == nil
               || newAlarmRadius == nil
               || newAlarmLocationLat == nil
               || newAlarmLocationLng == nil)
    }

    var body: some View {
        DetailEditor(title: "New Alarm",
                     color: color,
                     saveDisabled: saveDisabled,
                     onSave: save) {
            Picker("Type", selection: $newAlarmType) {
                ForEach(BethinkeryAlarmKind.allCases, id: \.self) { alarmType in
                    Text(alarmType.title).tag(alarmType)
                }
            }
            .pickerStyle(.segmented)

            switch newAlarmType {
                case .relativeTimeAlarm:
                    Section {
                        HStack(alignment: .center) {
                            Picker("Time Amount", selection: $newAlarmOffsetAmount) {
                                ForEach(Array(stride(from: 1.0, to: 100.0, by: 1.0)),
                                        id: \.self) { num in
                                    Text(num, format: .number.rounded(rule: .up, increment: 1.0))
                                        .tag(num)
                                }
                            }
                            .pickerStyle(.wheel)
                            Picker("Time Units", selection: $newAlarmOffsetUnit) {
                                ForEach(TimeAlarmIntervalUnits.allCases, id: \.self) { unit in
                                    Text(String(describing: unit)).tag(unit)
                                }
                            }
                            .pickerStyle(.wheel)
                            Picker("Relative Time Direction", selection: $newAlarmOffsetDirection) {
                                ForEach(TimeAlarmIntervalDirection.allCases, id: \.self) { dir in
                                    Text(String(describing: dir)).tag(dir)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                    Section {
                        HStack {
                            Spacer(minLength: 0)
                            if let relativeAnchorAlarm = alarmList.earliestAlarm {
                                Text(relativeAnchorAlarm.isAllDay ?
                                     Formatters.allDayFormatter.string(from: relativeAnchorAlarm.time) :
                                        Formatters.dateFormatter.string(from: relativeAnchorAlarm.time))
                            } else {
                                Text("No exact time alarm set")
                                    .foregroundStyle(.red)
                            }
                            Spacer(minLength: 0)
                        }
                    } footer: {
                        // swiftlint:disable:next line_length
                        Text("Relative alarms are based on the earliest Exact Time alarm set on the Reminder. If no Exact Time alarm is set, this alarm will never be triggered. If the earliest alarm changes (an earlier one is added or the earliest is deleted) all Relative alarms will automatically be based on the new earliest Exact Time alarm.")
                    }

                case .absoluteTimeAlarm:
                    if newAlarmIsAllDay {
                        DatePicker("Alarm Date",
                                   selection: $newAlarmTime,
                                   displayedComponents: [.date])
                    } else {
                        DatePicker("Alarm Time",
                                   selection: $newAlarmTime,
                                   displayedComponents: [.date, .hourAndMinute])
                    }
                    Toggle("All day", isOn: $newAlarmIsAllDay)
                        .onChange(of: newAlarmIsAllDay) { _, isAllDay in
                            if isAllDay {
                                newAlarmTime = Calendar.current.startOfDay(for: newAlarmTime)
                            }
                        }

                case .proximityAlarm:
                    Picker("Type", selection: $newAlarmProxType) {
                        ForEach(AlarmProximityType.allCases, id: \.self) { proxType in
                            if proxType != .nothing {
                                Text(proxType.title).tag(proxType)
                            }
                        }
                    }
                    Button {
                        LocationPicker(radius: $newAlarmRadius,
                                       name: $newAlarmTitle,
                                       address: $newAlarmAddress,
                                       lat: $newAlarmLocationLat,
                                       lng: $newAlarmLocationLng)
                    } label: {
                        if let newAlarmTitle {
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .font(.headline)
                                    .accessibilityLabel(Text("Location alarm"))
                                Text(newAlarmTitle)
                            }
                        } else {
                            Text("Select location")
                        }
                    }
            }
        } footer: {}
    }

    private func save() {
        switch newAlarmType {
            case .relativeTimeAlarm:
                let offset: TimeInterval = newAlarmOffsetAmount *
                newAlarmOffsetUnit.rawValue *
                TimeInterval(newAlarmOffsetDirection.rawValue)
                let newAlarm = RelativeTimeAlarmTemplate(id: nil, offset: offset)

                alarmList.append(newAlarm)
                dismiss()

            case .absoluteTimeAlarm:
                let newAlarm = AbsoluteTimeAlarmTemplate(
                    id: nil,
                    time: newAlarmTime,
                    isAllDay: newAlarmIsAllDay)

                alarmList.append(newAlarm)
                dismiss()

            case .proximityAlarm:
                guard let newAlarmTitle, let newAlarmRadius,
                      let newAlarmLocationLat, let newAlarmLocationLng else { return }
                let newAlarm = ProximityAlarmTemplate(
                    id: nil,
                    title: newAlarmTitle,
                    radius: newAlarmRadius,
                    locationLat: newAlarmLocationLat,
                    locationLng: newAlarmLocationLng,
                    proximityType: newAlarmProxType
                )

                alarmList.append(newAlarm)
                dismiss()
        }
    }
}
