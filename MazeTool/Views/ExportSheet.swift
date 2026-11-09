import SwiftUI

/// Picks which PNGs to export, shows what they look like, and hands them to the share sheet.
struct ExportSheet: View {
    enum Selection: String, CaseIterable, Identifiable {
        case both = "Both"
        case maze = "Maze"
        case overlay = "With overlays"

        var id: Self { self }

        var styles: [MazeExport.Style] {
            switch self {
            case .both: MazeExport.Style.allCases
            case .maze: [.maze]
            case .overlay: [.overlay]
            }
        }
    }

    let document: MazeDocument

    @Environment(\.dismiss) private var dismiss
    @State private var selection = Selection.both
    @State private var files: [URL] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Images", selection: $selection) {
                    ForEach(Selection.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    ForEach(files, id: \.self) { file in
                        ExportThumbnail(file: file)
                    }
                }
                .frame(maxHeight: .infinity)

                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                ShareLink(items: files) {
                    Label(files.count == 1 ? "Share image" : "Share \(files.count) images", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(files.isEmpty)
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: selection, initial: true) { render() }
    }

    private var summary: String {
        let size = MazeExport.pixelSize(of: document)
        return "Transparent PNG, \(Int(size.width)) × \(Int(size.height)) pixels. Always exported in the light look."
    }

    private func render() {
        do {
            files = try selection.styles.map { try MazeExport.writePNG(of: document, style: $0) }
            errorMessage = nil
        } catch {
            files = []
            errorMessage = "Couldn't create the images. \(error.localizedDescription)"
        }
    }
}

/// One exported image on a white card, since the PNG itself has no background.
private struct ExportThumbnail: View {
    let file: URL

    var body: some View {
        if let image = UIImage(contentsOfFile: file.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.4)))
        }
    }
}
