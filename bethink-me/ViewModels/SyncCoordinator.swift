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

    private let stream: AsyncStream<SyncReason>
    private let continuation: AsyncStream<SyncReason>.Continuation
    private var consumer: Task<Void, Never>?


    init() {
        (stream, continuation) = AsyncStream.makeStream(of: SyncReason.self,
                                                        bufferingPolicy: .bufferingNewest(1))
    }

    func start() {
        guard consumer == nil else { return }
        consumer = Task { [weak self, stream] in
            for await reason in stream {
                guard let self else { return }
                if reason != .initialized {
                    try? await Task.sleep(for: .milliseconds(kSyncRequestDebounceMilliseconds))
                    if Task.isCancelled {
                        break
                    }
                }
                await self.performSync(reason: reason)
            }
        }
    }

    func iJustMadeAChange() {
        lastChange = .now
    }

    func requestSync(reason: SyncReason) {
        continuation.yield(reason)
    }

    private func performSync(reason: SyncReason) async {
        guard let synchronizer else { return }
        switch reason {
            case .initialized:
                break // only once!
            case .foregrounded:
                if let lastSync,
                   Date.now.timeIntervalSince(lastSync) < kForegroundedSyncGracePeriodSeconds {
                    return
                }
                fallthrough
            case .EKChanged:
                if let lastChange,
                   Date.now.timeIntervalSince(lastChange) < kChangeGracePeriodSeconds {
                    return
                }
        }

        do {
            try await synchronizer()
            lastSync = Date.now
            hasEverSynced = true
        } catch {
            ErrorReporter().report(error, retry: { [weak self] in
                await self?.performSync(reason: reason)
            })
        }
    }

    deinit {
        continuation.finish()
    }
}
