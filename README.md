# Total Tossup Maze Tool

A small iPhone utility for drawing grid mazes by dragging. The mazes are layout guides for the hand-drawn, printed boards of Total Tossup, a pen-and-paper game.

Each finished maze holds two unicursal paths, one for the blue team and one for the red team, that weave around each other without connecting.

## Status

Early development. Working today:

- Document list with create, duplicate, rename and delete
- New-maze sheet with name, width, height and a live grid preview

Planned: path, double-path, room, marker and erase tools; validity checks; symmetry assistance; a two-tone preview.

## Building

Open `TotalTossupMazeTool.xcodeproj` in Xcode 26 or later and run the `MazeTool` scheme. The app targets iOS 26.

```bash
xcodebuild test -project TotalTossupMazeTool.xcodeproj -scheme MazeTool -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
