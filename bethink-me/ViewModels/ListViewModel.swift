import EventKit
import SwiftData
import SwiftUI


@MainActor
@Observable
final class ListViewModel {
    @AppStorage(SettingsKey.maxCompletedAgeDays.rawValue)
    @ObservationIgnored private var maxCompletedAgeDaysSetting: Int = kMaxCompletedAgeDaysDefault

    private let sharedModel: SharedViewModel

    var availableSources: [EKSource] = []
    var defaultSource: EKSource?


    init(sharedModel: SharedViewModel) {
        self.sharedModel = sharedModel
    }

    func loadLists() async throws {
//        try await Task.sleep(for: .milliseconds(1500))
        guard await sharedModel.checkPermissions() else {
            throw BethinkMeError("tried to loadLists without permissions")
        }

        let validSourceTypes = [EKSourceType.local, .exchange, .calDAV]
        let calendars = sharedModel.eventStore
            .calendars(for: .reminder)
            .filter({ validSourceTypes.contains($0.source.sourceType) })

        // reconcile the stored data with Reminders
        // assume EK is always the real source of truth and update ours accordingly
        // three possibilities:
        // = yes reminder, yes storage
        // | yes reminder, no storage
        // X no reminder, yes storage

        for ekcal in calendars {
            let existingLists = sharedModel.bethinkeryLists.filter({ $0.id == ekcal.calendarIdentifier })
            let currentList: BethinkeryList

            if existingLists.count == 1 {
                // = yes reminder, yes storage
                // make sure fields are in sync
                currentList = existingLists.first!
                currentList.load(from: ekcal)
            } else if existingLists.isEmpty {
                // | yes reminder, no storage
                // add it
                currentList = BethinkeryList(calendar: ekcal)
                sharedModel.modelContext.insert(currentList)
            } else {
                throw BethinkMeError("found multiple matching cal ids for \(ekcal.calendarIdentifier)")
            }

            let loadedReminders = await loadRemindersForCalendar(ekcal)
            for ekrem in loadedReminders {
                let existingBethinkeries = currentList.bethinkeries.filter({ $0.id == ekrem.calendarItemIdentifier })

                if existingBethinkeries.count == 1 {
                    // = yes reminder, yes storage
                    // make sure fields are in sync
                    let existingBethinkery = existingBethinkeries.first!
                    try existingBethinkery.load(from: ekrem)
                } else if existingBethinkeries.isEmpty {
                    // | yes reminder, no storage
                    // add it
                    let newReminder = try Bethinkery(reminder: ekrem, list: currentList)
                    currentList.bethinkeries.append(newReminder)
                    sharedModel.modelContext.insert(newReminder)
                } else {
                    throw BethinkMeError("found multiple matching rem ids for \(ekrem.calendarItemIdentifier)!")
                }
            }

            for danglingReminder in currentList.bethinkeries.filter({ savedBethinkery in
                // we never found an ekreminder to attach to this
                !savedBethinkery.hasReminder ||
                // the stored reminder's ekreminder no longer exists in the ekreminders for this list
                !loadedReminders.contains(where: { $0.calendarItemIdentifier == savedBethinkery.id })
            }) {
                // X no reminder, yes storage
                // remove it
                sharedModel.modelContext.delete(danglingReminder)
            }
        }

        for danglingList in sharedModel.bethinkeryLists.filter({ savedList in
            // we never found an ekcal to attach to this
            !savedList.hasCalendar ||
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
        if !calendars.isEmpty {
            let defaultCal = sharedModel.eventStore.defaultCalendarForNewReminders() ?? calendars.first!
            defaultSource = defaultCal.source
        }

        try sharedModel.modelContext.save()
    }

    func create(from createCommand: EditBethinkeryList, source: EKSource) throws {
        do {
            let newCalendar = EKCalendar(for: .reminder, eventStore: sharedModel.eventStore)
            newCalendar.source = source
            newCalendar.title = createCommand.title
            newCalendar.cgColor = Color(hex: createCommand.hexColor).cgColor

            try sharedModel.eventStore.saveCalendar(newCalendar, commit: true)

            let newBethinkeryList = BethinkeryList(calendar: newCalendar)
            sharedModel.modelContext.insert(newBethinkeryList)
            try sharedModel.modelContext.save()
            sharedModel.syncCoordinator.iJustMadeAChange()
            sharedModel.resetOrdinals()
        } catch {
            throw BethinkMeError("failed to save new List", from: error as NSError)
        }
    }

    func update(_ bethinkeryList: BethinkeryList, with updateCommand: EditBethinkeryList) throws {
        bethinkeryList.title = updateCommand.title
        bethinkeryList.hexColor = updateCommand.hexColor

        do {
            try sharedModel.eventStore.saveCalendar(bethinkeryList.toCalendar(), commit: true)
            sharedModel.syncCoordinator.iJustMadeAChange()
        } catch {
            throw BethinkMeError("failed to commit List update", from: error as NSError)
        }
    }

    func delete(_ bethinkeryList: BethinkeryList) throws {
        do {
            try sharedModel.eventStore.removeCalendar(bethinkeryList.toCalendar(), commit: true)
            sharedModel.modelContext.delete(bethinkeryList)
            try sharedModel.modelContext.save()
            sharedModel.syncCoordinator.iJustMadeAChange()
        } catch {
            throw BethinkMeError("failed to delete List", from: error as NSError)
        }
    }

    func moveListPosition(from: IndexSet, to: Int) throws {
        var tmpLists = sharedModel.bethinkeryLists
        tmpLists.move(fromOffsets: from, toOffset: to)

        for (idx, list) in tmpLists.enumerated() {
            list.ordinal = idx
        }

        try sharedModel.modelContext.save()
    }

    private func loadRemindersForCalendar(_ calendar: EKCalendar) async -> [EKReminder] {
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
                    continuation.resume(returning: reminders ?? [])
            }
        }
        async let incompleteds = withCheckedContinuation { continuation in
            sharedModel.eventStore.fetchReminders(matching: sharedModel.eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: [calendar])) { reminders in
                    continuation.resume(returning: reminders ?? [])
            }
        }

        let (fetchedCompleteds, fetchedIncompleteds) = await (completeds, incompleteds)
        return fetchedCompleteds + fetchedIncompleteds
    }

}
