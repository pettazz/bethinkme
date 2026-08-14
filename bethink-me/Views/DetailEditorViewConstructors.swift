import SwiftUI


struct DetailHeader: View {
    let title: String
    var subTitle: String?
    let color: Color

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(color)
            .font(.largeTitle)
            .bold()
            .padding(.horizontal, 20)
            .padding(.top, 10)
        if let subTitle {
            Text("in \(subTitle)")
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.primary)
                .font(.subheadline)
                .bold()
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
    }
}

struct DetailEditor<FormContent: View, Footer: View>: View {
    @Environment(\.dismiss)
    private var dismiss

    let title: String
    var subTitle: String?
    let color: Color

    var saveDisabled: Bool = false

    let onSave: () -> Void

    @ViewBuilder var formContent: () -> FormContent
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DetailHeader(title: title, subTitle: subTitle, color: color)
                Form {
                    formContent()
                }
                .contentMargins(.top, 10, for: .scrollContent)
                footer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .buttonStyle(.borderedProminent)
                        .disabled(saveDisabled)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddAlarmButton: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Add alarm")
                .padding(5)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .padding(.vertical, 15)
    }
}
