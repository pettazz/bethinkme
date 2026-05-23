import SwiftData
import SwiftUI

@main
struct bethink_meApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Lists", systemImage: "checklist") {
                    MainView()
                }
                Tab("Settings", systemImage: "gear") {
                    VStack {
                        Spacer()
                        Image(systemName: "figure.equestrian.sports")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text(Bundle.main.identifier)
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Ver: \(Bundle.main.appVersionLong)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("There's nothing to set yet")
                    }
                }
            }
        }
        .modelContainer(for: [Bethinkery.self, BethinkeryList.self])
    }
}
