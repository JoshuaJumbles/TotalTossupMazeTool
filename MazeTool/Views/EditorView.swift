import SwiftUI

/// Placeholder editor: shows the empty grid until the drawing tools land.
struct EditorView: View {
    let documentID: MazeDocument.ID

    @Environment(DocumentStore.self) private var store

    var body: some View {
        if let document = store.document(id: documentID) {
            GridPreview(width: document.width, height: document.height)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(document.name)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Maze not found", systemImage: "questionmark.square.dashed")
        }
    }
}
