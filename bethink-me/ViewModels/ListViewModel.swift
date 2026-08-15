import EventKit
import SwiftData
import SwiftUI


@MainActor
@Observable
final class ListViewModel {
    @AppStorage(SettingsKey.enableDedupe.rawValue)
    @ObservationIgnored private var enableDedupe: Bool = kEnableDedupeDefault
    @AppStorage(SettingsKey.dedupeCaseSensitive.rawValue)
    @ObservationIgnored private var dedupeCaseSensitive: Bool = kDedupeCaseSensitiveDefault
    @AppStorage(SettingsKey.dedupeRunOnSync.rawValue)
    @ObservationIgnored private var dedupeRunOnSync: Bool = kDedupeRunOnSyncDefault
    @AppStorage(SettingsKey.inheritListAlarmsOnImport.rawValue)
    @ObservationIgnored private var inheritListAlarmsOnImport: InheritListAlarmsOnImportOptions = kInheritListAlarmsOnImportDefault // swiftlint:disable:this line_length
    @AppStorage(SettingsKey.maxCompletedAgeDays.rawValue)
    @ObservationIgnored private var maxCompletedAgeDaysSetting: Int = kMaxCompletedAgeDaysDefault

    private let sharedModel: SharedViewModel

    var availableSources: [EKSource] = []
    var defaultSource: EKSource?


    init(sharedModel: SharedViewModel) {
        self.sharedModel = sharedModel
    }

    // swiftlint:disable:next cyclomatic_complexity
    func loadLists() async throws {
//        try await Task.sleep(for: .milliseconds(1500))
        guard sharedModel.hasAccess else {
            throw BethinkMeError("tried to loadLists without permissions")
        }

        let validSourceTypes = [EKSourceType.local, .exchange, .calDAV]
        let calendars = sharedModel.eventStore
            .calendars(for: .reminder)
            .filter({ validSourceTypes.contains($0.source.sourceType) && $0.allowsContentModifications })

        guard !calendars.isEmpty || sharedModel.bethinkeryLists.isEmpty else {
            sharedModel.syncStatus = .unavailable
            return
        }

        // reconcile the stored data with Reminders
        // assume EK is always the real source of truth and update ours accordingly
        // three possibilities:
        // = yes reminder, yes storage
        // | yes reminder, no storage
        // X no reminder, yes storage

        var dupesToDelete: [EKReminder] = []
        var needToInheritListAlarms: [Bethinkery] = []
        for ekcal in calendars {
            let existingLists = sharedModel.bethinkeryLists.filter({ $0.id == ekcal.calendarIdentifier })
            let currentList: BethinkeryList

            if existingLists.count == 1, let firstList = existingLists.first {
                // = yes reminder, yes storage
                // make sure fields are in sync
                currentList = firstList
                currentList.load(from: ekcal)
            } else if existingLists.isEmpty {
                // | yes reminder, no storage
                // add it
                currentList = BethinkeryList(calendar: ekcal)
                sharedModel.modelContext.insert(currentList)
            } else {
                throw BethinkMeError("found multiple matching cal ids for \(ekcal.calendarIdentifier)")
            }

            guard let loadedReminders = await loadRemindersForCalendar(ekcal) else {
                throw BethinkMeError("failed to load reminders for calendar \(ekcal.calendarIdentifier)")
            }
            for ekrem in loadedReminders {
                let existingBethinkeries = currentList.bethinkeries.filter({ $0.id == ekrem.calendarItemIdentifier })

                if existingBethinkeries.count == 1, let existingBethinkery = existingBethinkeries.first {
                    // = yes reminder, yes storage
                    // make sure fields are in sync
                    try existingBethinkery.load(from: ekrem)
                } else if existingBethinkeries.isEmpty {
                    // | yes reminder, no storage
                    // add it
                    let newReminder = try Bethinkery(reminder: ekrem, list: currentList)
                    if enableDedupe && dedupeRunOnSync && doesDuplicateExist(of: newReminder, in: currentList) {
                        dupesToDelete.append(ekrem)
                    } else {
                        currentList.bethinkeries.append(newReminder)
                        sharedModel.modelContext.insert(newReminder)

                        if inheritListAlarmsOnImport == .always ||
                            (inheritListAlarmsOnImport == .whenEmpty &&
                             (!newReminder.hasAlarms && currentList.hasAlarms)) {
                            needToInheritListAlarms.append(newReminder)
                        }
                    }
                } else {
                    throw BethinkMeError("found multiple matching rem ids for \(ekrem.calendarItemIdentifier)!")
                }
            }

            for danglingReminder in currentList.bethinkeries.filter({ savedBethinkery in
                // the stored reminder no longer exists in the ekreminders for this list
                !loadedReminders.contains(where: { $0.calendarItemIdentifier == savedBethinkery.id })
            }) {
                // X no reminder, yes storage
                // remove it
                sharedModel.modelContext.delete(danglingReminder)
            }
        }

        let liveSourceIds = Set(sharedModel.eventStore.sources.map(\.sourceIdentifier))
        for danglingList in sharedModel.bethinkeryLists.filter({ savedList in
            // the source is not unavailable to load
            liveSourceIds.contains(savedList.sourceId) &&
            // the stored list's ekcal no longer exists in the cals for this list
            !calendars.contains(where: { $0.calendarIdentifier == savedList.id })
        }) {
            // X no reminder, yes storage
            // remove it, also removes any reminders still attached to it
            sharedModel.modelContext.delete(danglingList)
        }

        // ensure we have ordinals set if we havent edited order before
        sharedModel.resetOrdinals()

        availableSources = sharedModel.eventStore.sources
            .filter({ validSourceTypes.contains($0.sourceType) })
        if !calendars.isEmpty, let firstCalendar = calendars.first {
            let defaultCal = sharedModel.eventStore.defaultCalendarForNewReminders() ?? firstCalendar
            defaultSource = defaultCal.source
        }

        if !dupesToDelete.isEmpty || !needToInheritListAlarms.isEmpty {
            try sharedModel.withTransaction { transaction in
                for dupe in dupesToDelete {
                    try transaction.stageRemove(dupe)
                }
                for bethinkery in needToInheritListAlarms {
                    let alarms = bethinkery.list.alarmTemplates.compactMap({ $0.toTemplate(newInstance: true) })
                    try sharedModel.replaceAlarms(on: bethinkery,
                                                  with: alarms,
                                                  within: transaction)
                }
            }
        }

        try sharedModel.modelContext.save()
        sharedModel.syncStatus = .ok
        sharedModel.reload()
    }

    func doesDuplicateExist(of bethinkery: Bethinkery, in list: BethinkeryList) -> Bool {
        return list.liveOrderedBethinkeries.contains(where: { testBethinkery in
            bethinkery.id != testBethinkery.id && bethinkery.isDuplicate(of: testBethinkery,
                                                                         caseSensitive: dedupeCaseSensitive)
        })
    }

    func findDuplicates(in list: BethinkeryList) -> [Bethinkery] {
        var originals: [Bethinkery] = []
        var dupes: [Bethinkery] = []

        for bethinkery in list.liveOrderedBethinkeries {
            if originals.contains(where: { bethinkery.isDuplicate(of: $0, caseSensitive: dedupeCaseSensitive) }) {
                dupes.append(bethinkery)
            } else {
                originals.append(bethinkery)
            }
        }

        return dupes
    }

    func findAllDuplicates() -> DuplicateGroup {
        let result: [DuplicateGroup.DuplicateList] = sharedModel.bethinkeryLists.compactMap({ list in
            let dupes = findDuplicates(in: list)
            guard !dupes.isEmpty else { return nil }
            return DuplicateGroup.DuplicateList(id: list.id, title: list.title, bethinkeries: dupes)
        })
        return DuplicateGroup(lists: result)
    }

    func create(from createCommand: EditBethinkeryList, source: EKSource) throws -> BethinkeryList {
        do {
            return try sharedModel.withTransaction { transaction in
                let newCalendar = EKCalendar(for: .reminder, eventStore: sharedModel.eventStore)
                newCalendar.source = source
                newCalendar.title = createCommand.title
                newCalendar.cgColor = Color(hex: createCommand.hexColor).cgColor

                try transaction.stage(newCalendar)

                let newBethinkeryList = BethinkeryList(calendar: newCalendar)
                newBethinkeryList.alarmTemplates = createCommand.alarmTemplates.map({ $0.toModel() })

                transaction.insertModel(newBethinkeryList)
                sharedModel.resetOrdinals()

                return newBethinkeryList
            }
        } catch {
            throw BethinkMeError("failed to save new List", from: error as NSError)
        }
    }

    func update(_ bethinkeryList: BethinkeryList,
                with updateCommand: EditBethinkeryList,
                replaceBethinkeryAlarms: Bool = false) throws {
        do {
            try sharedModel.withTransaction { transaction in
                bethinkeryList.title = updateCommand.title
                bethinkeryList.hexColor = updateCommand.hexColor

                let existingAlarmIDs = Set(bethinkeryList.alarmTemplates.map(\.id))
                let updatedAlarmIDs = Set(updateCommand.alarmTemplates.map(\.id))

                for alarm in bethinkeryList.alarmTemplates where !updatedAlarmIDs.contains(alarm.id) {
                    bethinkeryList.alarmTemplates.removeAll(where: { $0.id == alarm.id })
                    transaction.deleteModel(alarm)
                }
                for template in updateCommand.alarmTemplates where !existingAlarmIDs.contains(template.id) {
                    let model = template.toModel()
                    transaction.insertModel(model)
                    bethinkeryList.alarmTemplates.append(model)
                }

                try transaction.stage(transaction.liveCalendar(for: bethinkeryList))

                if replaceBethinkeryAlarms {
                    do {
                        for bethinkery in bethinkeryList.liveOrderedBethinkeries {
                            try sharedModel
                                .replaceAlarms(on: bethinkery,
                                               with: bethinkeryList.alarmTemplates.compactMap(
                                                { $0.toTemplate(newInstance: true) }),
                                               within: transaction)
                        }
                    } catch {
                        throw BethinkMeError("failed to replace alarms on Bethinkery after list update",
                                             from: error as NSError)
                    }
                }
            }
        } catch {
            throw BethinkMeError("failed update BethinkeryList", from: error as NSError)
        }
    }

    func delete(_ bethinkeryList: BethinkeryList) throws {
        do {
            try sharedModel.withTransaction { transaction in
                try transaction.stageRemove(transaction.liveCalendar(for: bethinkeryList))
                transaction.deleteModel(bethinkeryList)
            }
        } catch {
            throw BethinkMeError("failed to delete List", from: error as NSError)
        }
    }

    func moveListPosition(from: IndexSet, to: Int) throws {
        try sharedModel.withTransaction { _ in
            var tmpLists = sharedModel.bethinkeryLists
            tmpLists.move(fromOffsets: from, toOffset: to)

            for (idx, list) in tmpLists.enumerated() {
                list.ordinal = idx
            }
        }
    }

    // returns [] when successfully fetched an empty list,
    // vs. nil when there was an error fetching
    private func loadRemindersForCalendar(_ calendar: EKCalendar) async -> [EKReminder]? {
        var ageLimitDateComponents = DateComponents()
        ageLimitDateComponents.day = -1 * maxCompletedAgeDaysSetting
        let ageLimitDate = Calendar.current.date(
            byAdding: ageLimitDateComponents,
            to: Date.now,
            wrappingComponents: false
        )

        async let completeds = withCheckedContinuation { continuation in
            sharedModel.eventStore.fetchReminders(matching: sharedModel.eventStore.predicateForCompletedReminders(
                withCompletionDateStarting: ageLimitDate,
                ending: Date.now,
                calendars: [calendar])) { reminders in
                    continuation.resume(returning: reminders)
            }
        }
        async let incompleteds = withCheckedContinuation { continuation in
            sharedModel.eventStore.fetchReminders(matching: sharedModel.eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: [calendar])) { reminders in
                    continuation.resume(returning: reminders)
            }
        }

        guard let fetchedCompleteds = await completeds,
              let fetchedIncompleteds = await incompleteds else {
                return nil
        }
        return fetchedCompleteds + fetchedIncompleteds
    }

}
