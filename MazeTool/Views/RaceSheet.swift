import SwiftUI

extension Team {
    var color: Color {
        switch self {
        case .blue: .blue
        case .red: .red
        }
    }
}

/// The at-a-glance race summary under the canvas: each team's move count and how many issues remain.
struct RaceChip: View {
    let analysis: MazeAnalysis

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Team.allCases, id: \.self) { team in
                HStack(spacing: 4) {
                    Circle()
                        .fill(team.color)
                        .frame(width: 10, height: 10)
                    Text(analysis.moves(for: team).map(String.init) ?? "–")
                        .monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(team.name): \(analysis.moves(for: team).map { "\($0) moves" } ?? "not finished")")
            }
            if !analysis.issues.isEmpty {
                Label("\(analysis.issues.count)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("\(analysis.issues.count) issues")
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

/// Race details: steps and moves per team, the steps-per-move rule, and the list of issues.
struct RaceSheet: View {
    @Bindable var model: EditorModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let analysis = model.analysis

        NavigationStack {
            List {
                Section {
                    ForEach(Team.allCases, id: \.self) { team in
                        LabeledContent {
                            Text(summary(of: team, in: analysis))
                        } label: {
                            Label {
                                Text(team.name)
                            } icon: {
                                Circle().fill(team.color).frame(width: 12, height: 12)
                            }
                        }
                    }
                    Stepper(
                        "Steps per move: \(model.stepsPerMove)",
                        value: $model.stepsPerMove,
                        in: MazeDocument.Settings.stepsPerMoveRange
                    )
                } footer: {
                    Text("Every corner and every room on a path is a stop. A step runs from one stop to the next.")
                }

                Section("Issues") {
                    if analysis.issues.isEmpty {
                        Label("No issues", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(analysis.issues, id: \.self) { issue in
                        Button {
                            model.highlightedIssue = issue
                            dismiss()
                        } label: {
                            Label(issue.message, systemImage: "exclamationmark.triangle")
                        }
                        .tint(.primary)
                        .disabled(issue.cells.isEmpty)
                    }
                }

                Section {
                    LabeledContent("Empty cells", value: "\(analysis.emptyCellCount)")
                }
            }
            .navigationTitle("Race")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func summary(of team: Team, in analysis: MazeAnalysis) -> String {
        guard let route = analysis.routes[team] else { return "No Start" }
        guard let steps = route.totalSteps, let moves = analysis.moves(for: team) else {
            return "Not finished · \(route.stepsWalked) steps so far"
        }
        return "\(steps) steps · \(moves) \(moves == 1 ? "move" : "moves")"
    }
}
