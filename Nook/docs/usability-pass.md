# Nook 0.7 — usability pass

Implemented the eight approved usability changes, with the owner's final sizing correction: items retain their size after editing. Additional content can grow a card downward; leaving an editor or removing words never shrinks/repositions it. Shapes change size only through explicit manual resizing.

## Behavior

1. **Undo/Redo:** visible header buttons and Ctrl/Command+Z, Shift+Ctrl/Command+Z (Ctrl/Command+Y also works). Up to 50 visit-local actions; refresh/closing clears history. Creation and its initial typing are one action; completed text/checklist editing coalesces autosaves. Selections, grouping, resizing, styles, connections, checklist edits and file actions can be reversed. Native text undo remains active inside editors. Title/account/sharing changes are not board history actions.
2. **Movement:** visible move grips on hover/selection, plus one shared selection grip. Unused object space still drags after a small movement threshold. A click without movement selects; written text remains single-click editable. No large invisible grip area is added.
3. **Predictable endings:** creation starts typing, while movement/resizing leave selection and canvas focus. Escape finishes editing and keeps selection. Checkbox and checklist removal controls remain independent of dragging.
4. **Navigation:** visible Select/Hand controls; Hand drags empty space to pan. Right/middle/Space drag shortcuts remain. Show everything fits the board. Mouse/Trackpad choice sits in Navigation settings.
5. **Sharing:** Invite opens a small Copy invitation link panel; Room focuses on people, code and owner approvals. Copying reuses the existing invitation, including after reload, without revoking guests. Replacement/disabling has a separate consequence/cancel dialog. First-time link creation preserves existing room-admitted guests. Owner-only authorization remains enforced.
6. **Readability:** stronger labels/status, larger handles/buttons, clear layer/color names and temporary-board lifetime/Keep this board information. Compact layouts separate lifetime and navigation controls. Nook logo/palette and exact eight-tool order are retained.
7. **Tool/file clarity:** descriptive tooltips. File opens a chooser before creating an object, then click-to-place with a filename preview. Toolbar dragging opens the chooser and retains the drop point. Native file drop uses the same validation/import path and coordinate conversion. Invalid, oversized, empty and overlong-name files receive early feedback. Cancel/Escape creates no placeholder.
8. **Stable sizing:** no automatic width compaction or exit-time shrink. Text/notes/ideas/checklists grow when needed; shapes keep chosen dimensions and warn during editing if their label needs more room. Existing manually sized objects remain available for deliberate resize. No internal canvas-item scrollbars are added. Connections retain text-aligned box-border attachment and obstacle routing.

## History safety and scope

Undo plans change only the properties involved in your own action. Independent collaborator changes remain. A competing change blocks undo/redo with an explanation; a server race still goes through normal revision/conflict protection. Deletion restoration includes links if both endpoints exist, and does not resurrect missing collaborators' endpoints. Undoing creation cannot remove a later collaborator connection unnoticed. Operations are atomic and use the same save/replay pipeline as normal edits.

History is in memory for the current board visit. It requires a connected board; an undo requested while a save is completing waits for acknowledgement. Reviewing a server conflict clears visit history so rejected drafts cannot become misleading undo entries. Existing device draft recovery remains separate and durable. History examines affected items rather than cloning the entire board on every edit.

## Invitation migration

An additive `invite_cipher` column stores an encrypted recoverable copy alongside the existing invitation hash, using the endpoint secret. It is never included in board snapshots and can be returned only through an authorized, CSRF-protected owner action. Revocation/claim/delete clear it. Old invitations with only a hash cannot be reconstructed: Copy reports that limitation and asks the owner to explicitly replace the invitation; it never silently rotates a working old link. Changing the endpoint secret can likewise require explicit replacement. Protect backups and the production secret.

## Checks

- 154 backend tests and 37 JavaScript tests passed, including reusable invitations, authorization, encrypted-token handling, key-order-independent history, coalescing, the 50-action limit, property conflicts, connection restoration, group reversal and file validation.
- Real HTTP/WebSocket smoke passed, including server-validated Undo/Redo, preserving a collaborator's independent text edit, restoring/deleting connections, existing admission/revocation, offline replay and multi-visitor atomic fanout.
- Browser: creation/delete/move/resize/appearance/file/checklist undo/redo; group/ungroup and multi-item nudge; no editor after manipulation; height growth then shortening (294px retained), manual resizing, reload persistence; Hand panning/Show everything; simple invitation reuse and replacement cancellation; shape label warning with unchanged 230x180 dimensions; compact 720px controls; no console errors.
- File chooser/placement was exercised with the local text fixture. Native operating-system file drag/drop was reviewed through its shared import/validation and coordinate path, but was not separately driven by browser automation.
- Production release built locally and boot-checked with HTTP serving disabled; original five legacy boards verified. No publishing or hosting.

Source backup: `.nook-history/before-usability-pass.zip`; pre-change database backup: `.nook-history/backup-20261109-182829-672.dump`. Preview: `docs/usability-0.7-preview.jpg`.
