import Foundation


@MainActor
@Observable
final class ErrorState {
    struct CurrentError {
        let error: BethinkMeError
        var retry: (() async throws -> Void)?
    }

    static let instance = ErrorState()
    private(set) var currentError: CurrentError?


    func report(_ error: BethinkMeError, retry: (() async throws -> Void)? = nil) {
        currentError = CurrentError(error: error, retry: retry)
    }

    @MainActor
    func doRetry() async {
        guard let err = currentError else { return }
        clear()
        do {
            try await err.retry?()
        } catch {
            ErrorReporter().report(error, retry: err.retry)
        }
    }

    func clear() {
        currentError = nil
    }
}
