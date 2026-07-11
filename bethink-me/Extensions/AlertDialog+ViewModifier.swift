import SwiftUI


struct AlertDialog: ViewModifier {
    @Binding var alertModel: AlertDialogModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $alertModel.isPresenting) {
                AlertDialogView(alertModel: alertModel)
                    .presentationDetents([.fraction(0.55)])
                    .interactiveDismissDisabled(true)
            }
    }
}

extension View {
    func alertDialogPresentable(alertModel: Binding<AlertDialogModel>) -> some View {
        modifier(AlertDialog(alertModel: alertModel))
    }
}
