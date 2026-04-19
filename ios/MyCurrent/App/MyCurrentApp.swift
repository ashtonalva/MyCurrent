import SwiftUI

@main
struct MyCurrentApp: App {
    @StateObject private var store = LocalStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
        }
    }
}
