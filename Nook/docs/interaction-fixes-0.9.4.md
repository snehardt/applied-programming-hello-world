# Nook 0.9.4 — creation mode and overlap previews

The owner approved the first two recommendations from the 0.9.3 review and excluded the third. Floating selection controls remain centered above the selected object/group, with the existing viewport-edge fallback. No collision avoidance for neighboring canvas elements was added.

Choosing a creation/connection tool leaves Hand and updates both the canvas cursor and Select/Hand pressed states. Actual placement also ensures Select, including direct keyboard placement. This fixes new cards being created without an active editor after panning. File placement follows the same rule; cancellation does not create anything.

Select underneath shows a temporary outline above covering objects when a choice is hovered or focused with the keyboard. The preview also includes a label, and choices have numbers and color cues. Choosing still performs normal selection/group expansion. The overlay is pointer-transparent and never enters board operations or persistence. Close/Escape, selection changes, paging and disappearing targets clear it.

Browser verification used a separate temporary board PTAYKG37NBOA4. Hand → Note accepted typing immediately; Hand → Task produced a writable checklist; direct keyboard Text placement also returned to Select with its editor active. Keyboard focus changed the preview target, mouse movement to a different row changed it again, and item styles/geometry/layers remained unchanged. Choosing selected the correct note and cleared the preview. The selected note's action bar was centered within 0.2 pixels and sat approximately 12 pixels above it.

155 ExUnit tests and 48 JavaScript tests passed. Source backup: .nook-history/before-0.9.4-mode-and-overlap.zip. No hosting or free drawing changes.
