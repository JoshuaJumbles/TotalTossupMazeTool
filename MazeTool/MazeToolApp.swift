import SwiftUI

@main
struct MazeToolApp: App {
    @State private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            DocumentListView()
                .environment(store)
        }
    }
}
