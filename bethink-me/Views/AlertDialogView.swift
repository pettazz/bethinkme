import SwiftUI


struct AlertDialogView: View {
    let alertModel: AlertDialogModel

    var body: some View {
        Spacer()
        VStack(alignment: .leading) {

            Text(alertModel.title)
                .font(.headline)
                .padding(.vertical, 15)

            Text(alertModel.message)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(.clear, in: RoundedRectangle(cornerRadius: 45))
        .padding(.horizontal, 25)
        .presentationBackground(.clear)
        .presentationCornerRadius(45)

        VStack(alignment: .center) {
            ForEach(Array(alertModel.actions.enumerated()), id: \.offset) { _, action in
                Button(role: action.role) {
                    action.action()
                    alertModel.dismiss()
                } label: {
                    Text(action.title)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 30)
                .padding(.bottom, 5)
            }

            if alertModel.showDefaultCancel {
                Button(role: .cancel) {
                    alertModel.dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 30)
                .padding(.top, 20)
                .padding(.bottom, 5)
                .tint(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.clear, in: RoundedRectangle(cornerRadius: 45))
        .padding(.horizontal, 25)
        .presentationBackground(.clear)
        .presentationCornerRadius(45)
    }
}

#Preview {
    let model = AlertDialogModel()
    model.isPresenting = true
    model.title = "Moving Reminder"
    // swiftlint:disable:next line_length
    model.message = "This Reminder has alarms and is being moved to a List with different alarms. Do you want to discard the existing alarms and replace them with the alarms from the new list?"
    model.actions = [
        ActionButton(title: "Click me", role: .destructive, action: { print("ok") }),
        ActionButton(title: "Do not click me", action: { print("no!") })
    ]
    model.showDefaultCancel = true
    return AlertDialogView(alertModel: model)
}
