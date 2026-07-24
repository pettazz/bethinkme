import SwiftUI


struct InvalidStateView: View {
    let icon: String
    let title: String
    let message: String

    var linkTitle: String?
    var linkURL: URL? = URL(string: UIApplication.openSettingsURLString)

    var retry: (() async throws -> Void)?

    var body: some View {
        // TODO: it also uggly
        VStack {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2)
                .foregroundColor(.gray)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)

            if let linkTitle, let linkURL {
                Link(linkTitle, destination: linkURL)
            }

            if let retry {
                Button {
                    Task { @MainActor in
                        try await retry()
                    }
                } label: {
                    Text("Retry")
                }

            }

            Spacer()
        }
    }
}


#Preview {
    InvalidStateView(icon: "hand.raised.square.on.square",
                     title: "Hahaha, Oh wow!",
                     message: "You really fucked up big time, who knows what's gonna happen now.",
                     linkTitle: "Enable me in settings"
    )
}
