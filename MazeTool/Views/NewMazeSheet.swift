import SwiftUI

struct NewMazeSheet: View {
    /// Called with name, width and height when the user taps Create.
    let onCreate: (String, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var width = MazeDocument.defaultWidth
    @State private var height = MazeDocument.defaultHeight

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(MazeDocument.untitledName, text: $name)
                }
                Section {
                    Stepper("Width: \(width)", value: $width, in: MazeDocument.sizeRange)
                    Stepper("Height: \(height)", value: $height, in: MazeDocument.sizeRange)
                }
                Section("Preview") {
                    MazeCanvas(maze: Maze(width: width, height: height), wallThickness: 1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("New maze")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, width, height)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NewMazeSheet { _, _, _ in }
}
