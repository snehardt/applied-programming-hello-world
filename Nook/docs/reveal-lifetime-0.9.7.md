# Nook 0.9.7 — automatic reveal restoration

The owner changed reveal lifetime: a cover should only stay hidden while the chosen item remains selected. This supersedes 0.9.6's manual-restoration-only behavior.

Choose Select underneath, then an outlined item. Its cover stays hidden while you type, drag, resize, format or save that selection. Editor blur by itself does not restore it. Click empty canvas, select something else, delete the chosen item, or otherwise lose that selection and the cover returns automatically. Group ownership is tracked separately from later selection additions so keeping another item selected does not prolong the original reveal after its owner is deselected.

The initial outline-choosing phase remains visible until you choose or cancel. Clicking empty space there cancels it. Reveal deeper intentionally resets to a new choosing phase while preserving the hidden stack. Show hidden items or Escape also clears selection and restores the scene. No saved layer/visibility fields change.

Verified on separate test board MJV2D7NIR75J4: typing, opening More options/editor blur and body dragging retained one hidden cover. Clicking a different item or empty canvas restored all covers. Clicking away before choosing also restored them. Deleting the revealed item restored the scene, and Undo restored the deleted test note. Browser logs had no errors. Automated checks: 155 backend and 49 JavaScript tests passed.
