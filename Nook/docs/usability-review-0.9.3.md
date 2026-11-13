# Nook 0.9.3 — selection placement and navigation review

Implemented the owner's two changes: Select underneath is a primary action again when applicable, and the selection bar sits above its item/group rather than in the lower-left corner. It tracks canvas transforms and falls back to a visible position near edges or toolbar obstructions. Its More options panel is positioned with it and constrained to the viewport. Pure geometry checks cover normal placement, edge clamping, flipping, toolbar avoidance and offscreen selections.

A separate temporary board was used for the walkthrough: V3HYGLXMQ2X5U. Notes were created/edited, duplicated, selected underneath and moved. Hand panning and small zoom adjustments worked. A two-item checklist supported Enter and Backspace on an empty third row. A connection was created and undone. Two notes were selected/grouped. Toolbar collapse/reopen and a 640x702 layout/menu check worked. Test content is separate from the owner's board; no owner-board elements were edited.

155 ExUnit tests and 48 JavaScript tests passed. Browser error logs were empty.

## Remaining critiques — not implemented in this pass

1. **Hand/creation conflict (confirmed):** choose Hand, then Note, then place. The note is created but its editor is not activated because Hand remains selected. Switching back to Select restores editing. Choosing a creation tool should automatically leave Hand; the user should not manage conflicting modes.
2. **Ambiguous overlap choices:** labels derive from type and text, so duplicated notes share a label. Add hover/focus highlighting of the prospective target and a small preview/color cue before choosing.
3. **Controls can obscure neighbors (observed):** the bar correctly stays above the selected group, but in a dense layout that space can contain a different task's text. Placement currently avoids workspace controls, not other canvas content. Prefer a free gap above/below and consider hiding nonessential controls during typing/dragging.

The app is easier to navigate, but this is an agent walkthrough, not evidence that first-time users will find every action. These remaining issues should be resolved before adding more tools or publishing.

## Follow-up — November 11

Recommendations 1 and 2 were approved and completed in 0.9.4. The owner excluded recommendation 3 and prioritized keeping the bar centered above the selected item/group. See interaction-fixes-0.9.4.md.
