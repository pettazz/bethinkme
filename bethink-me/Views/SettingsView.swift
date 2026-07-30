import SwiftUI
import UniformTypeIdentifiers


struct SettingsView: View {
    @AppStorage(SettingsKey.enableAutocorrect.rawValue)
    private var enableAutocorrect: Bool = kEnableAutocorrectDefault
    @AppStorage(SettingsKey.enableDedupe.rawValue)
    private var enableDedupe: Bool = kEnableDedupeDefault
    @AppStorage(SettingsKey.dedupeCaseSensitive.rawValue)
    private var dedupeCaseSensitive: Bool = kDedupeCaseSensitiveDefault
    @AppStorage(SettingsKey.dedupeRunOnSync.rawValue)
    private var dedupeRunOnSync: Bool = kDedupeRunOnSyncDefault
    @AppStorage(SettingsKey.dedupeNow.rawValue)
    private var dedupeNow: Bool = false
    @AppStorage(SettingsKey.maxCompletedAgeDays.rawValue)
    private var maxCompletedAgeDays: Int = kMaxCompletedAgeDaysDefault
    @AppStorage(SettingsKey.displayNotes.rawValue)
    private var displayNotes: Bool = kDisplayNotesDefault
    @AppStorage(SettingsKey.displayURLs.rawValue)
    private var displayURLs: Bool = kDisplayURLsDefault
    @AppStorage(SettingsKey.displayAlarmIcons.rawValue)
    private var displayAlarmIcons: Bool = kDisplayAlarmIconsDefault

    @State private var shouldShowVersionCopiedPopover: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable autocorrection", isOn: $enableAutocorrect)
                    Toggle(isOn: $enableDedupe) {
                        VStack(alignment: .leading) {
                            Text("Enable deuplication")
                            Text("Ignore new Reminders when they are identical to an existing one on the same list")
                                .font(.caption)
                        }
                        .containerRelativeFrame(.horizontal, count: 4, span: 2, spacing: 0)
                    }
                } header: {
                    Text("Editing")
                }

                if enableDedupe {
                    Section {
                        Toggle(isOn: $dedupeRunOnSync) {
                            VStack(alignment: .leading) {
                                Text("Deduplicate on sync")
                                // swiftlint:disable:next line_length
                                Text("When synchronizing changes made outside the app, delete new copies of existing Reminders")
                                    .font(.caption)
                            }
                            .containerRelativeFrame(.horizontal, count: 4, span: 2, spacing: 0)
                        }
                        Toggle(isOn: $dedupeCaseSensitive) {
                            VStack(alignment: .leading) {
                                Text("Case sensitive titles")
                                // swiftlint:disable:next line_length
                                Text("Whether to consider the same text in upper and lower case titles different when checking for duplicates")
                                    .font(.caption)
                            }
                            .containerRelativeFrame(.horizontal, count: 4, span: 2, spacing: 0)
                        }
                        VStack(alignment: .leading) {
                            if dedupeNow {
                                // swiftlint:disable:next line_length
                                Text("Deduplication check will run when you next switch back to the Lists tab, a notification will be shown if any are found")
                                    .font(.caption)
                            } else {
                                Button("Schedule a deduplication check") {
                                    dedupeNow = true
                                }
                                // swiftlint:disable:next line_length
                                Text("Runs when you next switch back to the Lists tab, a notification will be shown if any are found")
                                    .font(.caption)
                            }
                        }
                    } header: {
                        Text("Deduplication")
                    }
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
