import SwiftUI


struct BethinkeryDetailView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrectSetting: Bool = true

    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var editBethinkeryCommand: EditBethinkery = EditBethinkery()

//    @State private var dueDateEditorVisible: Bool = false
//    @State private var dueDatePickerValue: Date = .now

    @State private var newAlarmFormVisible: Bool = false
    @State private var newAlarmType: AvailableAlarmTypes = .absoluteTimeAlarm

    @State private var newAlarmTime: Date = Date.now

    @State private var newAlarmOffsetAmount: TimeInterval = 1
    @State private var newAlarmOffsetUnit: TimeAlarmIntervalUnits = .days
    @State private var newAlarmOffsetDirection: TimeAlarmIntervalDirection = .before

    @State private var newAlarmTitle: String?
    @State private var newAlarmAddress: String?
    @State private var newAlarmRadius: Double?
    @State private var newAlarmLocationLat: Double?
    @State private var newAlarmLocationLng: Double?
    @State private var newAlarmProxType: AlarmProximityType = .enter

    var model: ViewModel
    var bethinkery: Bethinkery

//    private var dueDateEnabled: Binding<Bool> {
//        Binding(
//            get: { editBethinkeryCommand.dueDate != nil },
//            set: { enabled in
//                if enabled {
//                    editBethinkeryCommand.dueDate = dueDatePickerValue
//                } else {
//                    editBethinkeryCommand.dueDate = nil
//                }
//            }
//        )
//    }

    var dateFormatter: DateFormatter {
        let it = DateFormatter()
        it.dateFormat = "MMM d"
        it.dateStyle = .medium
        it.doesRelativeDateFormatting = true

        return it
    }

    var body: some View {
        NavigationStack {
            VStack {
                // TODO: make this less ugly, see also BethinkeryListDetailView
                Text(editBethinkeryCommand.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(Color(hex: bethinkery.list.hexColor))
                    .font(.largeTitle)
                    .bold()
                    .padding(20)
                Form {
                    Section {
                        TextField(
                            editBethinkeryCommand.title,
                            text: $editBethinkeryCommand.title,
                            prompt: Text("Title"))
                        .autocorrectionDisabled(!enableAutocorrectSetting)

                        TextField(
                            "Notes",
                            text: $editBethinkeryCommand.notesText,
                            prompt: Text("Notes"),
                            axis: .vertical)

                        TextField(
                            "URL",
                            text: $editBethinkeryCommand.urlText,
                            prompt: Text("URL"))
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                    }

                    Section {
                        if bethinkery.hasAlarms {
                            ForEach(bethinkery.sortedAlarms) { alarm in
                                AlarmView(relativeAlarm: bethinkery.earliestAlarm, alarm: alarm)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withErrorReporter {
                                                try model.removeAlarm(alarm, from: bethinkery)
                                            }
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
                            .pickerStyle(.segmented)

                            switch newAlarmType {
                                case .relativeTimeAlarm:
                                    HStack(alignment: .center) {
                                        Picker("Units", selection: $newAlarmOffsetAmount) {
                                            ForEach(Array(stride(from: 1.0, to: 100.0, by: 1.0)), id: \.self) { num in
                                                Text(num, format: .number.rounded(rule: .up, increment: 1.0)).tag(num)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        Picker("Units", selection: $newAlarmOffsetUnit) {
                                            ForEach(TimeAlarmIntervalUnits.allCases, id: \.self) { unit in
                                                Text(String(describing: unit)).tag(unit)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        Picker("Units", selection: $newAlarmOffsetDirection) {
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
                                        withErrorReporter {
                                            try model.addAlarm(newAlarm, to: bethinkery)
                                        }
                                        newAlarmFormVisible.toggle()
                                    }

                                case .absoluteTimeAlarm:
                                    DatePicker("Select Alarm Time",
                                               selection: $newAlarmTime,
                                               displayedComponents: [.date, .hourAndMinute])
                                    Button("Save") {
                                        let newAlarm = AbsoluteTimeAlarm(time: newAlarmTime, isAllDay: false)
                                        withErrorReporter {
                                            try model.addAlarm(newAlarm, to: bethinkery)
                                        }
                                        newAlarmFormVisible.toggle()
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
                                        withErrorReporter {
                                            try model.addAlarm(newAlarm, to: bethinkery)
                                        }
                                        newAlarmFormVisible.toggle()
                                    }
                            }
                        }

                        Button(newAlarmFormVisible ? "Cancel" : "Add Alarm") {
                            withAnimation {
                                newAlarmFormVisible.toggle()
                            }
                        }
                    } header: {
                        Text("Alarms")
                    }

                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        withAnimation {
                            withErrorReporter {
                                try model.update(bethinkery, with: editBethinkeryCommand)
                            }
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    init(model: ViewModel, bethinkery: Bethinkery) {
        self.model = model
        self.bethinkery = bethinkery
        _editBethinkeryCommand = StateObject(wrappedValue: .fromBethinkery(bethinkery))
//        _dueDatePickerValue = State(initialValue: bethinkery.dueDate ?? .now)
    }
}
