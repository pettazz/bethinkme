import SwiftUI


struct RepeatableTextField: UIViewRepresentable {

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        var onSubmit: () -> Void
        var onDone: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void, onDone: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
            self.onDone = onDone
        }

        @objc
        func textChanged(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        @objc
        func doneTapped() {
            onDone()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return false
        }
    }


    @Binding var text: String

    var enableAutocorrect: Bool
    var returnKey: UIReturnKeyType = .next
    var onSubmit: () -> Void
    var onDone: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.borderStyle = .none
        field.autocorrectionType = enableAutocorrect ? .default : .no
        field.returnKeyType = returnKey
        field.enablesReturnKeyAutomatically = true
        field.addTarget(context.coordinator,
                        action: #selector(Coordinator.textChanged),
                        for: .editingChanged)

        let bar = UIToolbar()
        bar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Done",
                            style: .done,
                            target: context.coordinator,
                            action: #selector(Coordinator.doneTapped))
        ]
        bar.sizeToFit()
        field.inputAccessoryView = bar

        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onDone = onDone
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, onSubmit: onSubmit, onDone: onDone) }
}
