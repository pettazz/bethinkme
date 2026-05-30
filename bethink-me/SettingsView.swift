import SwiftUI
import UniformTypeIdentifiers

enum SettingsKey: String {
    case enableAutocorrect = "settings.enableAutocorrect"
    case maxCompletedAgeDays = "settings.maxCompletedAgeDays"
}

struct SettingsView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrect: Bool = true
    
    @AppStorage(SettingsKey.maxCompletedAgeDays.rawValue)
    private var maxCompletedAgeDays: Int = 30
    
    @State private var shouldShowVersionCopiedPopover: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable autocorrection", isOn: $enableAutocorrect)
                } header: {
                    Text("Editing")
                }
                
                Section {
                    Picker(selection: $maxCompletedAgeDays) {
                        Text("1 year").tag(365)
                        Text("6 months").tag(180)
                        Text("60 days").tag(60)
                        Text("30 days").tag(30)
                        Text("7 days").tag(7)
                        Text("1 day").tag(1) //TODO: remove dumb options for release
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Max completed age")
                            Text("Ignore any existing completed reminders older than this age")
                                .font(.caption)
                        }
                        .containerRelativeFrame(.horizontal, count: 4, span: 2, spacing: 0)
                    }
                } header: {
                    Text("Viewing")
                }
                
                VStack {
                    Image(systemName: "figure.equestrian.sports")
                        .font(.system(size: 60))
                    Text(Bundle.main.identifier)
                        .font(.title2)
                    Text("Version: \(Bundle.main.appVersionLong) (\(Bundle.main.appBuild))")
                        .font(.subheadline)
                    Text(Bundle.main.appGitReleaseVersion)
                        .font(.subheadline)
                        .monospaced()
                        .onTapGesture {
                            let clipboard = UIPasteboard.general
                            clipboard.setValue(Bundle.main.appGitReleaseVersion,
                                               forPasteboardType: UTType.plainText.identifier)
                            shouldShowVersionCopiedPopover = true
                        }
                        .popover(isPresented: $shouldShowVersionCopiedPopover,
                                 attachmentAnchor: .point(.center),
                                 arrowEdge: .top,
                                 content: {
                            Text("Copied!")
                                .padding()
                                .presentationCompactAdaptation(.none)
                        })
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            .navigationBarTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
