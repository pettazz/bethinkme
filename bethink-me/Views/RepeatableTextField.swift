import SwiftUI


struct RepeatableTextField: UIViewRepresentable {

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool

        var onSubmit: () -> Void
        var onDone: () -> Void
        var onBeginEditing: () -> Void
        var onEndEditing: () -> Void

        init(text: Binding<String>,
             isFocused: Binding<Bool>,
             onSubmit: @escaping () -> Void,
             onDone: @escaping () -> Void,
             onBeginEditing: @escaping () -> Void,
             onEndEditing: @escaping () -> Void) {
            _text = text
            _isFocused = isFocused
            self.onSubmit = onSubmit
            self.onDone = onDone
            self.onBeginEditing = onBeginEditing
            self.onEndEditing = onEndEditing
        }

        @objc
        func textChanged(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        @objc
        func doneTapped() {
            onDone()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !isFocused {
                isFocused = true
            }
            onBeginEditing()
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if isFocused {
                isFocused = false
            }
            onEndEditing()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return false
        }
    }


    @Binding var text: String
    @Binding var isFocused: Bool

    var enableAutocorrect: Bool
    var returnKey: UIReturnKeyType = .next
    var onSubmit: () -> Void
    var onDone: () -> Void
    var onBeginEditing: () -> Void = {}
    var onEndEditing: () -> Void = {}

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
        if isFocused != uiView.isFirstResponder {
            let shouldFocus = isFocused
            DispatchQueue.main.async {
                if shouldFocus { uiView.becomeFirstResponder() } else { uiView.resignFirstResponder() }
            }
        }
        uiView.autocorrectionType = enableAutocorrect ? .default : .no
        uiView.returnKeyType = returnKey
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onDone = onDone
        context.coordinator.onBeginEditing = onBeginEditing
        context.coordinator.onEndEditing = onEndEditing
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text,
                                                        isFocused: $isFocused,
                                                        onSubmit: onSubmit,
                                                        onDone: onDone,
                                                        onBeginEditing: onBeginEditing,
                                                        onEndEditing: onEndEditing) }
}
