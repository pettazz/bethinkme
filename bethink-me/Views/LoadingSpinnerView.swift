import SwiftUI


struct LoadingSpinnerView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .tint(.accentColor)
                .scaleEffect(2.0, anchor: .center)
                .padding()
            Text("Loading Bethinkeries...")
                .padding()
        }
        .padding()
        .transition(.blurReplace)
    }
}
