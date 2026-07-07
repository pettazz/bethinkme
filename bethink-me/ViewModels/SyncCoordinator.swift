import Foundation


enum SyncReason {
    case initialized
    case EKChanged
    case foregrounded
}

@MainActor
final class SyncCoordinator {
    var hasEverSynced: Bool = false
    var synchronizer: (() async throws -> Void)?

    private var lastSync: Date?
    private var lastChange: Date?

    private var syncInProgress: Bool = false
    private var pendingSync: Bool = false
    private var pendingReason: SyncReason = .EKChanged

    private var debouncer: Task<Void, Never>?

    var shouldPerformForegroundedSync: Bool {
        if lastSync != nil && Date.now.timeIntervalSince(lastSync!) < kForegroundedSyncGracePeriodSeconds {
            return false
        }
        return true
    }


    func iJustMadeAChange() {
        lastChange = .now
    }

    func requestSync(reason: SyncReason) async {
        if reason == .initialized {
            do {
                try await sync(reason: reason)
            } catch {
                ErrorReporter().report(error, retry: {
                    try await self.sync(reason: reason)
                })
            }
        } else {
            debouncer?.cancel()
            debouncer = Task {
                try? await Task.sleep(for: .milliseconds(kSyncRequestDebounceMilliseconds))
                guard !Task.isCancelled else { return }

                do {
                    try await sync(reason: reason)
                } catch {
                    ErrorReporter().report(error, retry: {
                        try await self.sync(reason: reason)
                    })
                }
            }
        }
    }

    private func sync(reason: SyncReason) async throws {
        guard synchronizer != nil else { return }

        if syncInProgress {
            pendingSync = true
            pendingReason = reason
            return
        }

        if reason != .initialized,
           let lastChange,
           Date.now.timeIntervalSince(lastChange) < kChangeGracePeriodSeconds {
            return
        }

        syncInProgress = true
        defer {
            syncInProgress = false
            if pendingSync {
                pendingSync = false
                Task { try await sync(reason: pendingReason) }
            }
        }

        try await synchronizer!()
        lastSync = Date.now
        hasEverSynced = true
    }
}
