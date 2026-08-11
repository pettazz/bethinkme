import SwiftUI

struct BethinkMeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    var from: NSError?
    let callStack: [String] = Thread.callStackSymbols
    var file: String
    var function: String
    var line: Int

    init(_ message: String,
         file: String = #fileID,
         function: String = #function,
         line: Int = #line) {
        self.message = message
        self.file = file
        self.function = function
        self.line = line
    }

    init(_ message: String,
         from: NSError,
         file: String = #fileID,
         function: String = #function,
         line: Int = #line) {
        self.message = message
        self.from = from
        self.file = file
        self.function = function
        self.line = line
    }
}

public struct ErrorReporter: ModalSheet {
    func report(_ error: any Error, retry: (() async throws -> Void)? = nil) {
        let castError = error as? BethinkMeError ?? BethinkMeError(
            "failed to retrieve error details",
            from: error as NSError
        )
        ErrorState.instance.report(castError, retry: retry)
        if Bundle.env == Env.debug || Bundle.env == Env.testFlight {
            present(ErrorDetailView(error: castError))
        } else {
            // TODO: telemetry!
        }
    }
}

extension View {
    func tryTask<ResultType>(
            _ task: Task<ResultType, Error>,
            retry: (() async throws -> Void)? = nil) async -> ResultType? {
        var result: ResultType?

        do {
            result = try await task.value
        } catch {
            ErrorReporter().report(error, retry: retry)
        }

        return result
    }

    func withErrorReporter<ResultType>(
            _ perform: () throws -> ResultType,
            retry: (() async throws -> Void)? = nil) -> ResultType? {
        var result: ResultType?

        do {
            result = try perform()
        } catch {
            ErrorReporter().report(error, retry: retry)
        }

        return result
    }
}

struct ErrorDetailView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State private var viewDidAppear: Bool = false

    var error: BethinkMeError

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "ladybug")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .accessibilityHidden(true)
                Text("Oh look! A bug!")
                    .font(.title2)
                // swiftlint:disable:next all
                Text("You're seeing this message because you are using a build type of either `testFlight` or `debug`. \nPlease report it by **taking a screenshot**, opening the **\(Image(systemName: "square.and.arrow.up")) share menu**, then tapping the **\(Image(systemName: "square.and.pencil")) Share beta feedback** button.")
                    .font(.caption)
                Spacer()

                ScrollView {
                    ErrorDetailViewRow(title: "msg", content: error.localizedDescription)
                    ErrorDetailViewRow(title: "loc", content: "\(error.function) \(error.file):\(error.line)")
                    if let fromErr = error.from {
                        ErrorDetailViewRow(title: "frmdbg", content: fromErr.debugDescription)
                    }
                    ErrorDetailViewRow(title: "build", content: Bundle.main.appGitReleaseVersion)
                    ErrorDetailViewRow(
                        title: "stack",
                        content: [
                            error.callStack.count >= 2 ? error.callStack[1] : "n/a",
                            error.callStack.count >= 3 ? error.callStack[2] : "n/a"
                        ].joined(separator: "\n"))

                }
                .background(Color.indigo)
                .cornerRadius(16.0)

                Spacer()
                Text("The app may be in a broken state now, please try quitting with the button above.")
                    .font(.caption)
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Quit App", role: .destructive) {
                        exit(0)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding()
        .onAppear {
            viewDidAppear = true
        }
        .sensoryFeedback(.error, trigger: viewDidAppear)
    }
}

struct ErrorDetailViewRow: View {
    var title: String
    var content: String

    private let spacing = 10.0

    var body: some View {
        VStack {
            HStack {
                Text(title)
                    .bold()
                    .font(.caption)
                    .containerRelativeFrame(.horizontal, count: 6, span: 1, spacing: spacing)
                Text(content)
                    .monospaced()
                    .font(.caption)
                    .containerRelativeFrame(.horizontal, count: 6, span: 5, spacing: spacing, alignment: .leading)
            }
            Divider()
        }
        .padding(.top, spacing)
    }
}
