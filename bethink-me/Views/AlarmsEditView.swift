import SwiftUI


struct AlarmsEditView: View {
    @State private var newAlarmFormVisible: Bool = false
    @State private var newAlarmType: AvailableAlarmTypes = .absoluteTimeAlarm

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

    var bethinkery: Bethinkery
    let scrollProxy: ScrollViewProxy?

    let onAdd: (BethinkeryAlarm) -> Void
    let onDelete: (BethinkeryAlarm) -> Void

    var body: some View {
        Section {
            if bethinkery.hasAlarms {
                ForEach(bethinkery.alarms.sortedAlarms) { alarm in
                    AlarmView(relativeAlarm: bethinkery.alarms.earliestAlarm, alarm: alarm)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDelete(alarm)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }

            }

            if newAlarmFormVisible {
                Picker("Type", selection: $newAlarmType) {
                    ForEach(AvailableAlarmTypes.allCases, id: \.self) { alarmType in
                        Text(alarmType.rawValue).tag(alarmType)
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
                            let newAlarm = RelativeTimeAlarm(offset: offset)

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
                            let newAlarm = AbsoluteTimeAlarm(
                                time: newAlarmTime,
                                isAllDay: newAlarmIsAllDay)

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
                            let newAlarm = ProximityAlarm(
                                title: titleCleaned.isEmpty ? newAlarmAddress! : titleCleaned,
                                radius: newAlarmRadius!,
                                location: LatLng(lat: newAlarmLocationLat!, lng: newAlarmLocationLng!),
                                type: newAlarmProxType
                            )

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
