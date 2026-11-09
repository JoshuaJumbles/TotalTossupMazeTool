import SwiftUI

extension Symmetry {
    var title: String {
        switch self {
        case .off: "Symmetry off"
        case .leftRight: "Mirror left and right"
        case .topBottom: "Mirror top and bottom"
        case .rotate: "Rotate 180°"
        }
    }

    var shortTitle: String {
        switch self {
        case .off: "Off"
        case .leftRight, .topBottom: "Mirror"
        case .rotate: "Rotate"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "circle.slash"
        case .leftRight: "arrow.left.and.right"
        case .topBottom: "arrow.up.and.down"
        case .rotate: "arrow.triangle.2.circlepath"
        }
    }
}

/// Shows the current symmetry and opens a menu to change it.
struct SymmetryChip: View {
    @Binding var symmetry: Symmetry

    var body: some View {
        Menu {
            Picker("Symmetry", selection: $symmetry) {
                ForEach(Symmetry.allCases) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            Label(symmetry.shortTitle, systemImage: symmetry.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(symmetry == .off ? Color.secondary : Color.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
        }
        .accessibilityLabel("Symmetry: \(symmetry.title)")
    }
}
