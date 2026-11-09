import SwiftUI

/// The app-wide light or dark choice. System follows the phone's setting.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Display settings: wall thickness for this maze and the app's appearance.
struct SettingsSheet: View {
    @Bindable var model: EditorModel

    @Environment(\.dismiss) private var dismiss
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Wall thickness", value: model.wallThickness.formatted(.number.precision(.fractionLength(1))))
                    Slider(value: $model.wallThickness, in: MazeDocument.Settings.wallThicknessRange, step: 0.5) {
                        Text("Wall thickness")
                    }
                } header: {
                    Text("This maze")
                }

                Section("App") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
