# Nook 0.9.2 — workspace organization

The standing text above/below the board is now in Help at the top right. This includes current-tool guidance, interaction instructions, board lifetime and the link/action to keep a temporary board. Save state stays in the header; meaningful offline/conflict notices still appear when needed.

The tool dock and collapse toggle live together at the upper-left. Select/Hand/zoom/settings stay 16 pixels from the lower-right edges. Selection actions stay 16 pixels from the lower-left; below 650 pixels wide they move above the navigation row to avoid collisions.

A single selection exposes Colors, Delete and More options. More options contains text size/color, Duplicate, Select underneath, shape/icon changes, grouping, position locking and layer controls when applicable. Stationary right-click on any item opens the same menu; right-drag keeps panning. Shift+F10 also opens it for the current selection. Escape closes a popup before clearing selection.

Validation: 155 backend and 47 JavaScript tests passed; browser checks at 797px and 640px show the corner layout and three-action bar; Help retains board information; right-click opens the advanced menu. Color-picker and overlapping-item actions remain reachable.

Changes are backed up before this pass in .nook-history/before-0.9.2-workspace-layout.zip. Nook stays local and unpublished.
