# Total Tossup Maze Tool

A small iPhone and iPad utility for drawing grid mazes by dragging. The mazes are layout guides for the hand-drawn, printed boards of Total Tossup, a pen-and-paper game.

Each finished maze holds two unicursal paths, one for the blue team and one for the red team, that weave around each other without connecting.

## Status

Early development. Working today:

- Document list with create, duplicate, rename and delete
- New-maze sheet with name, width, height and a live grid preview
- Path tool: drag to carve a connected corridor
- Double tool: drag along a grid line to carve two parallel corridors, one on each side
- Room tool: drag a diagonal to place a rectangular room
- Mark tool: tap a room to cycle blue Start, red Start, End
- Erase tool, with undo and redo per stroke
- Race overlay: team colour along each path, a step number at every stop, and a badge where each move ends
- Race chip and sheet: moves per team, steps per move, and a list of issues
- Symmetry: mirror left and right, mirror top and bottom, or rotate 180°, applied to every stroke while it is on
- Preview: a two-tone view of the bare maze with every editor overlay hidden
- Settings: wall thickness per maze, and a light, dark or system appearance for the app
- Zoom: pinch to zoom up to 5×, drag with two fingers to pan, one finger still draws
- iPad: runs in any orientation; in landscape the tools move beside the maze
- Export: transparent PNGs of the bare walls, the walls with editor overlays, or both, through the share sheet
- Mazes save after every stroke


## Building

Open `TotalTossupMazeTool.xcodeproj` in Xcode 26 or later and run the `MazeTool` scheme. The app targets iOS 26.

```bash
xcodebuild test -project TotalTossupMazeTool.xcodeproj -scheme MazeTool -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
