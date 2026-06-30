import SwiftUI
import UniformTypeIdentifiers


let kMaxCompletedAgeDaysDefault = 30

struct SettingsView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrect: Bool = true
    @AppStorage(SettingsKey.maxCompletedAgeDays.rawValue)
    private var maxCompletedAgeDays: Int = kMaxCompletedAgeDaysDefault
    @AppStorage(SettingsKey.displayNotes.rawValue)
    private var displayNotes: Bool = false
    @AppStorage(SettingsKey.displayURLs.rawValue)
    private var displayURLs: Bool = false
    @AppStorage(SettingsKey.displayAlarmIcons.rawValue)
    private var displayAlarmIcons: Bool = false

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
                        Text("1 day").tag(1) // TODO: remove dumb options for release
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Max completed age")
                            Text("Ignore any existing completed reminders older than this age")
                                .font(.caption)
                        }
                        .containerRelativeFrame(.horizontal, count: 4, span: 2, spacing: 0)
                    }
                    Toggle("Show Notes", isOn: $displayNotes)
                    Toggle("Show URLs", isOn: $displayURLs)
                    Toggle("Show Alarm Icons", isOn: $displayAlarmIcons)
                } header: {
                    Text("Viewing")
                }

                Section {
                    Button("Trigger the error reporter") {
                        withErrorReporter {
                            throw BethinkMeError("hahaha, oh wow", from: NSError(
                                domain: "Demozone",
                                code: 1701,
                                userInfo: ["key": "value", "NSLocalizedDescripton": "i made it up!"]))
                        } retry: {
                            print("hehehe")
                        }
                    }
                } header: {
                    Text("Devtools")
                }

                VStack {
                    Image(systemName: "figure.equestrian.sports")
                        .font(.system(size: 60))
                        .accessibilityHidden(true)
                    Text(Bundle.main.identifier)
                        .font(.title2)
                    Text("Version: \(Bundle.main.appVersionLong) (\(Bundle.main.appBuild)) - \(Bundle.env.rawValue)")
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
                        .accessibilityAddTraits(.isButton)
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

                VStack {
                    Image(systemName: "batteryblock.stack.fill")
                        .font(.system(size: 60))
                        .accessibilityHidden(true)
                    Text("Acknowledgements")
                        .font(.title2)

                    Text("LocationRadiusPicker")
                        .font(.headline)
                    HStack {
                        Link("[Source]", destination: URL(string: "https://github.com/birkoof/LocationRadiusPicker")!)
                            .font(.subheadline)
                        Link("[MIT License]", destination:
                                URL(string: "https://github.com/birkoof/LocationRadiusPicker/blob/main/LICENSE")!)
                            .font(.subheadline)
                    }
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
