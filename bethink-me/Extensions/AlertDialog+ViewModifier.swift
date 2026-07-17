import SwiftUI


struct AlertDialog: ViewModifier {
    @Binding var alertModel: AlertDialogModel

    @State private var sheetContentHeight = CGFloat(0)

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $alertModel.isPresenting) {
                AlertDialogView(alertModel: alertModel)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self,
                                      of: { geometry in
                                          return geometry.size.height
                                      }, action: { newValue in
                                          sheetContentHeight = newValue
                                      })
                    .presentationDetents([.height(sheetContentHeight)])
                    .interactiveDismissDisabled(true)
            }
    }
}

extension View {
    func alertDialogPresentable(alertModel: Binding<AlertDialogModel>) -> some View {
        modifier(AlertDialog(alertModel: alertModel))
    }
}
