# Nook 0.9.5 — consistent dragging, hover choices and quick text

The owner asked for shape-style movement across all items. Entire card/icon/text-box bodies now receive the pointer. Drag from blank space to move; written words retain editing and text selection. Click without movement on an editable single card to focus its editor. Icons select on click and drag from their center, including transparent space. Position locks and multi-selection/group behavior still apply. Select underneath is the way to reach covered objects; the previous icon-interior/plain-text-layout click-through behavior is superseded.

Checklist text areas distinguish rendered words from unused row space using a hidden browser text measurement. Empty row space drags the card; a stationary click focuses that row. Checkboxes, add/remove buttons, links and resize handles retain their actions. The pointer switches between text and move accordingly.

Hover or focus Shapes/Icons to reveal choices beneath the respective button. A short close delay allows crossing the gap into the panel. Keyboard ArrowDown moves into the chooser. Choosing a shape/icon activates that tool and retains the exact variant for placement or dragging from the toolbar. Ordinary button clicks still open the choices.

Double-click empty canvas to create a text box with the caret at the clicked position. No account is required. Double-clicks on existing items, controls and active placement tools do not create an extra box.

Verified on separate temporary board HIBL4AJCA2ZNO: one text box on double-click; immediate typing; unused text-box area dragged without editing; note blank-area drag and stationary click-to-edit; transparent warning-icon center drag; mouse-hover shape choices without activating a tool; exact diamond placement; keyboard icon chooser; checklist blank-row drag; preserved completion and text editing. Browser error logs were empty. Automated checks: 155 backend and 48 JavaScript tests passed.

Source backup: .nook-history/before-0.9.5-drag-and-tool-choices.zip. No hosting or free drawing changes.

Additional regression checks: double-clicking a note leaves the text-box count unchanged; double-clicking empty canvas in Hand creates exactly one new text box and returns to Select. The handler checks the actual visual target after pointer capture.
