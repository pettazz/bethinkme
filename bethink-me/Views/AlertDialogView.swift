import SwiftUI


struct AlertDialogView: View {
    @Environment(\.colorScheme)
    var colorScheme

    let alertModel: AlertDialogModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                Text(alertModel.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(uiColor: .label))
                    .padding(.top, 30)

                Text(alertModel.message)
                    .padding(.vertical, 10)
                    .fontWeight(.regular)
                    .foregroundStyle(Color(uiColor: .label))
                    .multilineTextAlignment(.leading)
            }
            .font(.body)
            .fontWeight(.regular)
            .foregroundStyle(.primary)
            .tint(.accentColor)
            .frame(maxWidth: .infinity)
            .presentationBackground(.clear)

//            VStack(spacing: 0) {
//                Text("diff stuff goes here!")
//            }
//            .padding(.horizontal, 25)
//            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 45))

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
                    .padding(.vertical, 5)
                }

                if alertModel.showDefaultCancel {
                    Button(role: .cancel) {
                        alertModel.dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .foregroundStyle(colorScheme == .dark ? .gray : .black)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 30)
                    .padding(.top, 15)
                    .padding(.bottom, 10)

                }
            }
            .frame(maxWidth: .infinity)
            .presentationBackground(.clear)
        }
        .padding(.horizontal, 25)
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
