import SwiftUI


struct LoadingSpinnerView: View {
    var message: String = "Loading..." // TODO: get a little cute with this "reticulating splines" style

    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .tint(.accentColor)
                .scaleEffect(2.0, anchor: .center)
                .padding()
            Text(message)
                .padding()
        }
        .padding()
        .transition(.blurReplace)
    }
}
