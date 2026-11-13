# Nook 0.8 — second usability review fixes

The seven issues in the November 10 review are implemented. Future feature ideas are recorded separately in `backlog.md`; none were added in this pass. Nook remains local and unpublished.

## Changes

1. **Safe Hand mode.** Left-drag pans over item text, backgrounds, move grips and resize handles without entering editing or manipulating items. Checklist action buttons and file links retain their normal click actions. Task text fields are read-only in Hand mode. Select restores ordinary editing/manipulation.
2. **Plain-text pointer targets.** A stable layout rectangle still controls wrapping/resizing, but only rendered words and explicit grips/handles capture pointer input outside editing. Blank space inside that layout area behaves like canvas, including marquee selection. Text remains single-click editable. Stored geometry is not compacted or shifted.
3. **Short selection controls.** Color, size, Duplicate, Delete and More options remain in the primary row. Text color, layers, groups, file replacement and connection options are secondary. The redundant Fit height control is hidden. Escape closes More options without discarding the selection.
4. **History continuity.** Up to 50 actions are retained in same-tab session storage across refresh and revisiting the board. Offline Undo/Redo updates the local board and queues guarded reversals. After earlier pending operations are acknowledged, each reversal is checked against the authoritative board and receives fresh revisions only when its expected values still match. Independent collaborator changes remain; competing changes open a review with force-keep disabled. Guard data is never sent over the channel. Inline notices explain blocked/queued actions. Storage failures explicitly warn, and stale persisted history is removed. Closing the tab or clearing browser storage ends this history; the app is not an offline-first/PWA page loader.
5. **Returning to boards.** The landing page lists up to 12 recently opened boards on this browser, with names and temporary/permanent status. Only metadata is cached, and the list never bypasses server authorization or expiration. Existing guest boards visited before this feature are not automatically discoverable; opening them now adds them. A naming reminder appears after an owner has added two items to an untitled board.
6. **Guided connections.** Connect mode shows connection ports, highlights valid targets, snaps nearby releases, and gives first-item/next-item/failed-drop/success guidance. Explicit port choices remain anchored. Shape ports are projected onto actual outlines, including sloped triangle edges. New connection history accounts for the server's default layer.
7. **Growing/oversized content.** Growth that overlaps another item shows a dismissible notice and marks the neighbor; it never moves either item automatically. Oversized shape labels keep their chosen geometry and show guidance when selected or editing. More options → Make text fit explicitly reduces the label font down to 12px; if that still cannot fit, it explains that fewer words or deliberate manual resizing is needed. Normal editing never silently changes shape or font size.

## Verification

- 154 backend tests and 43 JavaScript tests passed; warnings-as-errors compilation and syntax checks passed.
- Real HTTP/WebSocket multiplayer/Undo/Redo smoke passed, including independent collaborator preservation, connection restoration, revocation, rejoin replay and multi-visitor atomic fanout.
- Browser verified Hand over note text pans without editing/moving; blank space beside short text hits the canvas and excludes that item from a marquee; direct text editing and the short/advanced options row work.
- Browser verified history survives refresh; with Phoenix stopped, a text edit was undone and redone offline; after restart all queued actions saved, and Undo/Redo still worked after refresh. A failed connection drop gives guidance, then a port-to-port connection can be created, undone, redone and recovered after refresh.
- Browser verified naming a board, finding it in Recents and reopening it; growth from 200px to 294px warns about a neighboring note while both positions remain unchanged; Make text fit changed a seven-line shape label from 16px to 12px while its 230x180 geometry stayed fixed.
- Compact 720px toolbar sizing and Escape menu dismissal were checked. Browser console errors were empty. Original five-board legacy data comparison, local release build and HTTP-disabled production boot check passed.
- Preview: `usability-0.8-preview.jpg`. Backups: `.nook-history/before-0.8-usability.zip` and `.nook-history/backup-20261110-140350-296.dump`. No schema migration was required for this pass.

The later ideas—collapsible toolbar, right-click shape changes, drawing, a shared color wheel and colored icons replacing Idea—remain deferred in `backlog.md`.
