import SwiftUI


struct RepeatableTextField: UIViewRepresentable {

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        var onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }

        @objc
        func textChanged(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return false
        }
    }


    @Binding var text: String

    var enableAutocorrect: Bool
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.borderStyle = .none
        field.autocorrectionType = enableAutocorrect ? .default : .no
        field.returnKeyType = .next
        field.addTarget(context.coordinator,
                        action: #selector(Coordinator.textChanged),
                        for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.onSubmit = onSubmit
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, onSubmit: onSubmit) }
}
