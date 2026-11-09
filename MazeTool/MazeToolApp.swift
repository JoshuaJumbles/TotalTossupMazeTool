import SwiftUI

@main
struct MazeToolApp: App {
    @State private var store = DocumentStore()
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system

    var body: some Scene {
        WindowGroup {
            DocumentListView()
                .environment(store)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
