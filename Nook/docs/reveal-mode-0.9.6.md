# Nook 0.9.6 — direct reveal mode

Select a cover and choose **Select underneath**. That item (or selected group) is temporarily hidden in your tab. Every overlapping remaining item has a visible outline and a clickable label. Select an outline/label or exposed item, then drag its blank space or edit its words normally. No list popup is shown.

The selected revealed item is temporarily elevated only in the DOM, so other remaining layers cannot block editing. Its original saved layer stays unchanged. Other outlines remain visible but their labels and border hit targets stop intercepting the active item's content. Click empty canvas to return to choosing among outlines. Outlined labels are staggered and keyboard accessible. **Reveal deeper** hides another selected cover when more overlapping items remain.

The cover does not return on blur, a save acknowledgement, drag completion or leaving the editor. Choose **Show hidden items** or press Escape outside editing to restore the normal view. Escape inside an editor first finishes editing; a subsequent Escape restores the view. Reload resets the local reveal state. Editing/geometry changes save normally, while hiding and local elevation never enter board operations or other participants' views.

Removed item-side and multi-selection move grips. Blank card bodies provide movement. Resize handles and internal checklist row-reordering handles remain.

Verification on separate board MJV2D7NIR75J4: three overlapping notes; one hidden cover and two outlined choices; bottom item selected, edited, moved and edited again while the cover remained hidden through acknowledgements; saved z values stayed 1 while the active item used a temporary CSS layer. A second tab saw zero hidden elements while the first had one. Show hidden items restored everything and removed outlines; deeper reveal hid two covers and left one choice; Escape from an editor kept both hidden until leaving reveal mode. No .move-grip controls remained. Automated checks: 155 ExUnit and 49 JavaScript tests passed.

The owner board was not edited. The sample notes are disposable local test data. No publication or free drawing changes.

## Updated lifetime in 0.9.7

The owner changed the rule: hidden covers now return when the chosen item loses selection. See reveal-lifetime-0.9.7.md; this supersedes the manual-only lifetime above.
