import SwiftData
import SwiftUI

@main
struct bethink_meApp: App { // swiftlint:disable:this type_name
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Lists", systemImage: "checklist") {
                    MainView()
                }
                Tab("Settings", systemImage: "gear") {
                    SettingsView()
                }
            }
        }
        .modelContainer(for: [
            Bethinkery.self,
            BethinkeryAlarm.self,
            BethinkeryList.self
        ])
    }


    init() {
        UserDefaults.registerSettingsDefaults()
    }
}
