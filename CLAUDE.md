# Total Tossup Maze Tool

Personal iPhone app (SwiftUI, iOS 26) for drawing two-team unicursal grid mazes. See README.md for the pitch.

## Workflow

- Branch from `main`; name branches `<category>/<kebab-case-name>` (`feat/`, `fix/`, `chore/`, `docs/`).
- One PR per change, squash-merged.
- UI changes include simulator screenshots committed to `docs/screenshots/` and linked in the PR body.

## Layout

- `MazeTool/Model` — pure Swift maze data and validation, no SwiftUI imports.
- `MazeTool/Persistence` — `DocumentStore`, one JSON file per maze in `Documents/Mazes`.
- `MazeTool/Views` — SwiftUI screens.
- `MazeToolTests` — Swift Testing unit tests for model and persistence.

The Xcode project uses file-system-synchronized groups, so new files under these folders need no project edits.

## Design rules

- Team colour is never stored; it is derived by following connections from Start markers.
- Symmetry is an editor toggle applied per stroke, not a document property.
- Validity checks inform and never block editing.
