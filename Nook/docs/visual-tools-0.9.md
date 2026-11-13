# Nook 0.9.0 — visual tools and workspace controls

Use **Hide tools / Tools** to recover canvas space. Your browser remembers the choice and shows the selected tool while collapsed. The toolbar stays open initially; there is no hover-only reveal.

Right-click a shape without moving to open shape choices. Right-drag still pans after a five-pixel movement threshold. The same choices are under **More options → Change shape**. Shape changes preserve dimensions, words, colors and links. Undo restores the previous shape.

Select an item and choose **Colors…** for a quick palette or native custom color chooser. Choose fill/icon versus text, then Apply custom color. Eight recent custom colors are remembered on this browser. Contrast feedback is advisory; colors are never changed automatically. Plain text uses text color, icons use stroke color, cards/shapes use fill.

**Icons** replaces Idea for new items: lightbulb, arrow, question, warning, checkmark, person, heart, document. Search the small collection, choose, then click to place or drag from the toolbar. Resize and recolor normally; **More options → Change icon** replaces an existing symbol. A document icon is not a file upload, and an arrow icon is not an attached connection. Existing Idea cards are unchanged.

**Navigation settings → Alignment guides and snapping** remembers your preference. Moves snap edges or centers within six screen pixels; selected groups move together. Hold Alt to bypass. Arrow nudges remain exact. Guides disappear on release/cancel. No automatic rearrangement.

**More options → Lock position** prevents drag movement, arrow nudges and manual resize. A selection containing a locked item is blocked as a whole. Unlock from the same menu. Content editing and downward growth remain available, and explicit deletion remains undoable. This is a shared convenience setting, not security authorization.

Validation: 155 ExUnit and 46 JavaScript checks; real WebSocket icon/color/lock broadcast and persistence; existing multiplayer/history smoke; browser checks of icon placement, custom colors/contrast, shape change/Undo/Redo, lock/refresh/nudge protection, collapse/refresh, alignment and unsnapped five-pixel movement. Five legacy boards retain every original field and title. The 0.9.0 release builds and boots with HTTP serving disabled. Backup created before changes in .nook-history.

Free drawing and stroke grouping are deliberately deferred. Nothing is published.

## 0.9.1: overlapping items

Empty space inside and around icon strokes passes pointer actions to what is behind it. Click the painted icon to select/move the icon itself. When items still cover each other, select one and choose **Select underneath**, then choose the named note, shape, file or other item. The list shows up to six choices per page, front to back. Selection preserves groups and does not change layer order.

A floating grip appears above overlapping content, so you can drag the chosen item even when its own grip is covered. Position locks still prevent moving/resizing. Escape closes the chooser without clearing selection.

Verified on the owner's reported overlapping warning-icon board. Note and covered shape moved independently; the test moves were undone. Full tests: 155 backend and 47 JavaScript checks passed.
