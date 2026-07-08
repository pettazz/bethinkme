import SwiftUI


struct AlarmsEditView: View {
    @State private var newAlarmFormVisible: Bool = false
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

    @State var alarmList: [any BethinkeryAlarmTemplate]
    let scrollProxy: ScrollViewProxy?

    let onAdd: (any BethinkeryAlarmTemplate) -> Void
    let onDelete: (any BethinkeryAlarmTemplate) -> Void

    @ViewBuilder private var alarmsList: some View {
        if !alarmList.isEmpty {
            ForEach(alarmList.sortedAlarms, id: \.id) { alarm in
                AlarmView(relativeAlarm: alarmList.earliestAlarm, alarm: alarm)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            alarmList.removeAll(where: { $0.id == alarm.id })
                            onDelete(alarm)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    var body: some View {
        Section {
            self.alarmsList

            if newAlarmFormVisible {
                Picker("Type", selection: $newAlarmType) {
                    ForEach(BethinkeryAlarmKind.allCases, id: \.self) { alarmType in
                        Text(alarmType.title).tag(alarmType)
                    }
                }
                .id("newAlarmForm")
                .pickerStyle(.segmented)

                switch newAlarmType {
                    case .relativeTimeAlarm:
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
                        Button("Save") {
                            let offset = newAlarmOffsetAmount *
                            newAlarmOffsetUnit.rawValue *
                            TimeInterval(newAlarmOffsetDirection.rawValue)
                            let newAlarm = RelativeTimeAlarmTemplate(id: nil, offset: offset)

                            alarmList.append(newAlarm)
                            onAdd(newAlarm)

                            withAnimation {
                                newAlarmFormVisible.toggle()
                            }
                        }

                    case .absoluteTimeAlarm:
                        if newAlarmIsAllDay {
                            DatePicker("Select Alarm Date",
                                       selection: $newAlarmTime,
                                       displayedComponents: [.date])
                        } else {
                            DatePicker("Select Alarm Time",
                                       selection: $newAlarmTime,
                                       displayedComponents: [.date, .hourAndMinute])
                        }
                        Toggle("All day", isOn: $newAlarmIsAllDay)
                        Button("Save") {
                            let newAlarm = AbsoluteTimeAlarmTemplate(
                                id: nil,
                                time: newAlarmTime,
                                isAllDay: newAlarmIsAllDay)

                            alarmList.append(newAlarm)
                            onAdd(newAlarm)

                            withAnimation {
                                newAlarmFormVisible.toggle()
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
                            if newAlarmTitle != nil || newAlarmAddress != nil {
                                let titleCleaned = newAlarmTitle!.trimmingCharacters(in: .whitespaces)
                                HStack {
                                    Image(systemName: "location.circle.fill")
                                        .font(.headline)
                                        .accessibilityLabel(Text("Location alarm"))
                                    Text(titleCleaned.isEmpty ? newAlarmAddress! : titleCleaned)
                                }
                            } else {
                                Text("Select location")
                            }
                        }
                        Button("Save") {
                            guard (newAlarmTitle != nil || newAlarmAddress != nil)
                                    && newAlarmRadius != nil
                                    && newAlarmLocationLat != nil
                                    && newAlarmLocationLng != nil else { return }
                            let titleCleaned = newAlarmTitle!.trimmingCharacters(in: .whitespaces)
                            let newAlarm = ProximityAlarmTemplate(
                                id: nil,
                                title: titleCleaned.isEmpty ? newAlarmAddress! : titleCleaned,
                                radius: newAlarmRadius!,
                                locationLat: newAlarmLocationLat!,
                                locationLng: newAlarmLocationLng!,
                                proximityType: newAlarmProxType
                            )

                            alarmList.append(newAlarm)
                            onAdd(newAlarm)

                            withAnimation {
                                newAlarmFormVisible.toggle()
                            }
                        }
                        .disabled(!((newAlarmTitle != nil || newAlarmAddress != nil)
                                    && newAlarmRadius != nil
                                    && newAlarmLocationLat != nil
                                    && newAlarmLocationLng != nil))
                }
            }

            Button(newAlarmFormVisible ? "Cancel" : "Add Alarm") {
                resetAddAlarmForm()
                withAnimation {
                    newAlarmFormVisible.toggle()
                }
            }
        } header: {
            Text("Alarms")
        }
        .onChange(of: newAlarmFormVisible) { _, isVisible in
            guard isVisible && scrollProxy != nil else { return }
            withAnimation {
                scrollProxy!.scrollTo("newAlarmForm", anchor: .top)
            }
        }
        .onChange(of: newAlarmType) {
            guard newAlarmFormVisible && scrollProxy != nil else { return }
            withAnimation {
                scrollProxy!.scrollTo("newAlarmForm", anchor: .top)
            }
        }
    }

    func resetAddAlarmForm() {
        newAlarmType = .absoluteTimeAlarm
        newAlarmTime = Date.now
        newAlarmIsAllDay = false
        newAlarmOffsetAmount = 1
        newAlarmOffsetUnit = .days
        newAlarmOffsetDirection = .before
        newAlarmTitle = nil
        newAlarmAddress = nil
        newAlarmRadius = nil
        newAlarmLocationLat = nil
        newAlarmLocationLng = nil
        newAlarmProxType = .enter
    }
}
