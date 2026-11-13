# 0.9.11 — Task titles remain accessible when idle (November 11, 2026)

- Reproduced the remaining title failure: an untitled task's title had display:none outside editing, so the earlier click-target fix did not help after clicking away or reloading. A second rule also removed empty placeholders outside editing.
- Task cards now always show an Add a title header when untitled, including cards marked as legacy checklists. The entire header is an editing target; blank card body space still moves the card.
- Reserved title height in checklist sizing so rows cannot overlap the header. Empty title DOM is normalized after blur so deleting a title restores the prompt even if contenteditable left a line-break element.
- Browser checks on separate test board XBC52QV23E3T4 confirmed display:none before the fix, visible Add a title while idle afterward, title entry without x/y movement, clearing/reloading/re-entering a title, and preserved checklist contents. Compilation/format checks and 155 backend/49 JavaScript tests passed.
- Source backup: .nook-history/before-0.9.11-task-title-access.zip. No owner-board edits or publishing.

# 0.9.10 — Place tools anywhere on the canvas (November 11, 2026)

- Active click-to-place tools now handle the canvas pointer before existing items, text editors, controls, endpoints or resize handles can consume it. Connect and panning keep their own behavior.
- The placement click is consumed, so underlying checkboxes/buttons/links do not also activate. New elements retain normal front-layer placement and editing focus. Placement cursors stay distinct over existing content.
- Browser verification on separate board KXUXJSV44HDCA: placed a circle directly on existing note words without changing its text or position; placed text directly on a task checkbox without checking it or editing the row; after ending placement, the checkbox worked normally; dragged an icon from the toolbar onto the circle successfully. Browser error logs were empty.
- JavaScript tests: 49 passed. Compilation/format checks passed. No owner-board edits or publishing.
- Source backup: .nook-history/before-0.9.10-place-anywhere.zip.

# 0.9.9 — Delete selected items (November 11, 2026)

- Bare Delete removes a card selected by clicking its blank body, including when click-to-type has automatically focused its editor. This also covers newly placed items and keyboard-selected reveal targets before text editing begins.
- Clicking written text, typing, caret movement and native editing commands preserve normal text deletion. Checklist Backspace behavior is unchanged. Modified Delete shortcuts are not intercepted inside editors.
- Noneditable item selection moves focus back to the canvas, so a previously focused title/settings input cannot swallow Delete.
- Browser verification on separate board XBC52QV23E3T4: click-select/Delete removed a note, task and icon; Undo restored them. Clicking note words and Home/Delete changed abcdef to bcdef while retaining the note. JavaScript checks: 49 passed. Compilation/format checks passed. No owner-board deletions or publishing.
- Source backup: .nook-history/before-0.9.9-delete-selection.zip.

# 0.9.8 — Clickable task title (November 11, 2026)

- The visible empty task-title placeholder now counts as an editable title target instead of initiating card movement. Written title text remains directly editable; blank card space still drags normally.
- Named the title textbox Task title for keyboard/accessibility clarity.
- Verified in a separate browser test board: single-click the empty title, type a title, click/edit the written title with unchanged x/y, drag blank card space, and reload with the updated title retained. Compilation and format checks passed. No owner-board edits or publishing.
- Source backup: .nook-history/before-0.9.8-task-title.zip.

# 0.9.7 — Reveal follows selection (November 11, 2026)

- Hidden covers now return automatically when the chosen revealed item/group is deselected, replaced by a different selection, deleted, or otherwise disappears.
- Covers remain hidden during typing, editor blur, formatting, dragging and saving while that same item remains selected. Adding other items to the selection does not replace the original reveal owner.
- Clicking empty canvas before choosing cancels reveal. Reveal deeper deliberately starts another choosing phase and preserves the hidden stack. Explicit restoration/Escape also clears selection.
- Verification: 155 backend and 49 JavaScript tests passed; browser checks confirmed editing/blur/drag retention, restoration on another selection or empty click, initial choosing cancellation, deletion restoration and Undo. No owner-board content changed; no publishing/free drawing.
- Source backup: .nook-history/before-0.9.7-selection-reveal-lifetime.zip.

# 0.9.6 — Direct reveal mode and body dragging (November 11, 2026)

- Replaced the Select underneath list with an on-canvas reveal mode. The selected cover/group disappears in this tab, and overlapping items receive outlines and clickable labels.
- Selecting a revealed item keeps it accessible locally above its neighbors for dragging, typing and resizing. Other outlines remain visible but stop intercepting the selected item's edits. Click empty canvas to choose again; Reveal deeper hides another cover.
- Covers stay hidden through edits, movement, saves and Undo until Show hidden items or Escape. Leaving an editor with Escape does not immediately restore the cover. Reload naturally resets this local view state.
- Hiding and temporary elevation never change saved content/layer order or another collaborator's view. Connections to hidden covers hide locally. Removed targets are pruned; hidden items are excluded from marquee/select-all and snapping.
- Removed per-item and multi-selection side move grips. Drag blank item space instead. Kept resize handles and internal checklist reorder controls.
- Verified 155 backend and 49 JavaScript tests, browser editing/moving while covers remain hidden, deeper reveals, explicit restoration/Escape, no move-grip DOM controls, unchanged saved layers, and a second tab seeing every item normally.
- Source backup: .nook-history/before-0.9.6-reveal-underneath.zip. Nothing published; no free drawing changes.

# 0.9.5 — Consistent dragging and quick text (November 11, 2026)

- Item bodies now drag like shapes, including plain-text layout space and the transparent center of icons. Written text retains editing/native text selection; checkbox, add/remove, link and resize controls keep their actions. Select underneath remains available for covered objects.
- An unmoved click on a single editable card focuses its editor; movement does not activate editing. Blank checklist-row space can drag the card, while written row text edits normally.
- Shapes and Icons reveal choices below their toolbar buttons on hover/focus. The pointer can cross into a popup, keyboard ArrowDown opens it, and choosing a variant activates its placement tool. Click-to-open remains available.
- Double-clicking empty canvas creates one focused text item at the clicked position. Existing items and controls are excluded.
- Kept centered item controls, position locks, grouping and Hand navigation. This supersedes earlier click-through behavior for icon interiors and unused plain-text box space, per the owner's new request.
- Verification: 155 backend and 48 JavaScript tests; browser checks for double-click text, plain-text/note blank-space dragging, click-to-edit, icon-center dragging, hover/keyboard variant selection, checklist blank-area dragging and preserved checkbox/text actions. No publishing or free drawing.

# 0.9.4 — Creation mode and overlap previews (November 11, 2026)

- Choosing a canvas tool automatically returns from Hand to Select. Placement also ensures Select for keyboard/drag entry points, so new text, notes and checklists can accept typing immediately. Explicit Hand selection still pans normally.
- Overlap-list choices now show a temporary canvas outline on hover or keyboard focus, including the group's bounds when applicable. Numbered rows and color cues help distinguish repeated titles.
- Previewing is local UI only: no element positions, layer order or saved content change. Closing, paging, changing selection and deleted targets clear stale previews.
- Preserved the centered selection bar above the selected item/group. No neighbor-avoidance behavior was added, per the owner's direction.
- Verification: 155 backend and 48 JavaScript tests; browser checks for Hand → Note/Task/keyboard Text creation, mouse and keyboard overlap previews, cleanup, unchanged item geometry/layers, correct target selection and centered controls. Nook remains local; no free drawing or publishing.

# 0.9.3 — Item-local selection controls (November 10, 2026)

- Restored Select underneath to the primary selection bar, visible when another item overlaps the selection.
- Positioned selection controls above the selected item or group. Controls track movement, panning and zoom, remain readable at screen scale, and flip/clamp near viewport edges or the creation toolbar. Connection controls anchor to their endpoints.
- More options follows the item-local bar and stays inside the viewport.
- Verified 155 backend tests and 48 JavaScript tests, plus a separate browser walkthrough: note creation/editing, duplicate, selection underneath, move, Hand panning, zoom, checklist Enter/Backspace, connections/Undo, group selection, toolbar collapse and 640px menu reachability. The owner's board content was not edited.
- Review findings retained for the next pass: choosing a creation tool in Hand leaves editing blocked; similar overlap choices need visual preview/highlighting; floating controls can cover neighboring canvas content. No free drawing or publication.

# 0.9.2 — Quieter workspace (November 10, 2026)

- Moved standing tool instructions and board lifetime/account-saving details into a labeled Help button in the top-right header. Kept save/reconnection/conflict feedback available.
- Docked creation tools at the upper-left, navigation at the bottom-right, and selection actions at the bottom-left, all with consistent edge spacing. On narrow windows selection actions sit above navigation to avoid overlap.
- Selection now initially shows only Colors, Delete and More options. Moved Duplicate, Select underneath, text size and other controls into More options. The same menu opens on stationary right-click for any item; right-drag still pans. Shape changes remain available inside that menu.
- Removed the instructional toast after selecting an overlapping item. Fixed custom text colors displaying as a blank choice in More options.
- Existing element manipulation, color picker, overlapping-item selection, position locks and keyboard shortcuts remain available. No publishing or free drawing changes.

# 0.9.1 — Reach overlapping items (November 10, 2026)

- Transparent areas around and inside icon strokes now click through to items underneath. The painted icon and its visible controls remain interactive.
- Added Select underneath for overlapping items, with named choices ordered front to back and six choices per page. Existing groups remain grouped; choosing never changes layers or positions.
- Added floating selection grips above overlapping content, so fully covered items can be moved or resized without moving their cover first. Position locks still apply.
- Escape closes the chooser and keeps the current selection. Overlap detection uses visible plain-text bounds and excludes connection lines.
- Verified 155 backend tests, 47 JavaScript tests, and the reported board in the browser: empty icon area selects the note; chooser selects covered note/shape; floating grips move only the chosen item; Undo restores test moves without changing layers. No hosting or free drawing changes.

# 0.9.0 — Visual tools and workspace controls (November 10, 2026)

- Added remembered Tools collapse with a visible active-tool label.
- Added right-click and More options shape changes; right-drag still pans.
- Added shared palette and custom color picker, eight recent custom colors, and text contrast feedback.
- Replaced new Idea creation with eight searchable, resizable colored Icons. Existing Idea cards are preserved. Document icons are symbols; File still uploads real files.
- Added optional alignment guides and snapping for single items and whole selections; Alt bypasses snapping. The preference survives refresh.
- Added undoable position locks: block move, nudge, and manual resize, including a selection containing a locked item. Content stays editable, can grow downward, and can be explicitly deleted. Locks are a shared usability setting, not an access permission.
- Validated icon names, boolean locks, and six-digit hex colors on the server; new metadata persists and broadcasts through existing collaboration.
- Free drawing, stroke grouping, publishing, and further appearance work remain deferred.

# Nook changelog

## 0.8.0 — 2026-11-10 — Second Usability Review Fixes

- Fixed Hand mode to pan over item content without accidental editing/movement, and plain-text hit targets to exclude blank layout space while keeping sizing stable.
- Simplified the selection row with secondary More options and removed redundant height fitting from the visible controls.
- Added same-tab refresh history persistence, offline guarded Undo/Redo, authoritative reconnect checks and inline explanations. History comparison now accounts for default connection layers.
- Added browser-local recent boards and a contextual naming reminder; server authorization/expiry still apply.
- Added visible connection ports on actual outlines, nearby-target highlighting/snapping and clear connection-step/drop feedback.
- Added overlap feedback during growth and explicit shape-label fitting without automatic shape resizing or moving neighbors.
- Recorded the owner's future ideas in `docs/backlog.md`; toolbar collapse, shape context menus, drawing, color wheels and icons remain deferred.
- Validation: 154 backend tests, 43 JavaScript tests, real multiplayer/Undo/Redo smoke, browser offline/refresh/recents/connection/growth/fitting checks, original legacy data preservation, local release build and HTTP-disabled boot. No publishing or hosting. See `docs/usability-0.8.md`.
- Backups retained; no schema migration required.


## 0.7.0 — 2026-11-09 — Predictable, Forgiving Canvas Workflows

- Implemented the eight approved usability changes: visit-local Undo/Redo; visible move/selection grips; distinct editing/manipulation endings; Select/Hand navigation; simpler reusable invitations and separate room controls; readability improvements; descriptive tools and choose-then-place/drop files; stable item sizing.
- Applied the owner's latest sizing correction: cards grow only as needed and never compact/shrink on leaving an editor or removing words. Shapes stay manually sized and warn about overflowing labels. No canvas-item scrollbars.
- Undo preserves independent collaborator edits, refuses competing edits, restores valid connections, coalesces editing sessions and uses atomic revision-checked saves. History is limited to 50 actions per visit and clears on refresh or conflict review.
- Added owner-only encrypted invitation recovery alongside hashed validation. Copying a link does not rotate it; explicit replace/disable actions explain guest revocation. Older hash-only invitations require explicit replacement rather than silent rotation. Additive migration only; existing boards retained.
- Fixed checklist growth incorrectly including the resize handle and semantic history comparison incorrectly depending on JSON key ordering.
- Validation: 154 backend tests, 37 JavaScript tests, server-verified Undo/Redo/multiplayer smoke, browser workflows, legacy preservation, local release build/HTTP-disabled boot. Native OS file drop was not separately automated; its shared validation/import path was reviewed. See `docs/usability-pass.md` for scope, evidence and limitations.
- Changes tracked; source/database backups retained. App remains local and unpublished.


## 0.6.0 — 2026-11-09 — Local Polish and Release Preparation

- Added durable opening/failure/retry screens, protected loading controls, offline editing feedback and accurate live save/reconnect state. Registration retains created accounts and explains retries when email delivery fails.
- Added keyboard tool placement, named dialogs, visible focus, skip-to-content, reduced-motion support and compact toolbar styling. Branded error pages provide safe navigation; original Nook identity and canvas behavior remain.
- Added restricted browser resource/permissions headers, generic liveness/readiness probes, strict production secrets/host/origins, HTTPS and secure cookies, configurable verified SMTP delivery, verified database TLS, and development-inbox exclusion.
- Added local release build/HTTP-disabled verification, a separate migration entry point, timestamped database backups with SHA-256 sidecars, isolated restore checks and operating/recovery documentation.
- Expanded real-session collaboration checks with actual disconnect/rejoin, safe independent offline replay, deduplication, four-visitor atomic fanout and concurrent independent edits.
- Validation: 151 backend tests and 26 JavaScript tests passed; real HTTP/WebSocket smoke, legacy preservation, isolated backup restoration, production build and HTTP-disabled release boot passed. Browser verified stopped-server draft/recovery/reload, keyboard creation, branded 404 and 720px toolbar fit. See `docs/production.md` for exact scope and remaining hosted-environment checks.
- Pre-change source/database backups: `.nook-history/before-milestone-6-source.zip` and `before-milestone-6.dump`. No destructive migration. **No hosting, external mail, public listener or publishing performed.**


## 0.5.6 — 2026-11-09 — Preserve Shape Sizes

- Shapes retain their chosen width and height while typing, leaving the editor, loading saved boards, and changing text appearance. Automatic content fitting excludes shapes; manual resize handles remain available.
- Text/white-note compaction, other card growth, border connections, obstacle routing and the no-internal-scrollbar rule are retained.
- Verification: 24 JavaScript tests passed. Browser checks confirmed a 230 by 180 shape stays exactly that size after multiline typing, blur, font-size changes, and reload. Screenshot: `docs/milestone-5.6-shape-sizes.jpg`.


## 0.5.5 — 2026-11-09 — Text-Aligned Connections and Obstacle Routing

- Automatic connections meet the outside of the item, aligned with the center of its written text. Explicitly positioned endpoints remain adjustable.
- Short plain text and white notes fit their words when editing ends, unless their width was manually set. Items continue to wrap and grow while typing without internal scrolling.
- Connections route around other canvas items with rounded bends and update when obstacles move. Clear paths retain the smooth curve. Routing is cached while geometry is unchanged.
- Verification: 24 JavaScript tests passed, including text-centered border ports, explicit anchors, reversed/vertical routes, and multiple obstacles. Browser checks cover drag-to-connect, compact text persistence, obstacle movement/rerouting, and clean console output. Screenshot: `docs/milestone-5.5-connections.jpg`.


## 0.5.4 — 2026-11-09 — Content Fits Without Scrollbars

- Canvas items never use internal scrolling. Text, notes, ideas, shapes, file labels and checklists grow while content is entered; checklist rows wrap and the containing card expands. Circle shapes grow equally in both dimensions.
- Previously saved content is fitted when displayed, and edits save the expanded geometry. Shortening text retains space until editing ends.
- Verification: 22 JavaScript tests passed; browser checks confirmed six checklist rows fit without scrolling and a seven-line idea expands immediately. Screenshot: `docs/milestone-5.4-no-scrollbars.jpg`.


## 0.5.3 — 2026-11-09 — Live Text Growth

- Notes and plain text wrap within their width and expand downward immediately while typing. The viewport follows the caret and synchronizes browser-induced scrolling with canvas coordinates. Growth is autosaved with the text; shortening content does not shrink the active editor, and height fits on exit.
- New text starts at 360px wide with an 18px font; new notes start at 320px wide with a 16px font. Existing board widths and font sizes are preserved.
- Existing checklist, cleanup, drag/focus, cursor and conflict behavior is retained. Height remains bounded by the existing 10,000px canvas limit.
- Verification: 22 JavaScript regression tests passed, including defaults and live height growth; browser checks cover wrapping, Enter/new-line growth, visibility while still editing, and saved geometry after reload. Screenshot: `docs/milestone-5.3-live-text.jpg`.

## 0.5.2 — 2026-11-09 — Editing and Checklist Corrections

- Text autosaves without changing box dimensions during editing. On leaving the editor/card, height fits the content while width stays as placed or manually resized. Circle proportions remain fixed.
- Clicking written text enters editing with native caret placement; other object space drags it. Text at the start/end of resized boxes remains accessible. Placement, single-object movement and resizing focus the text automatically; task placement focuses its first item.
- Empty plain-text and idea elements are removed when editing ends. Placeholder text is limited to editing; completed idea cards retain only their content, without the decorative bulb/empty scaffolding.
- Task rows use wrapping text areas and separate spacing. Enter adds a row, Shift+Enter adds a line within it, and Backspace on an empty row removes it and focuses the previous row. The visible X removes its row without a blur handler re-adding it.
- The gap above Add task is a clickable insertion area. Add/delete controls take priority over dragging, and internal focus changes do not trigger card resizing. Task descriptions are removed from the interface; existing stored descriptions are retained for data preservation.
- Fixed a creation-acknowledgement race that could show a conflict when typing immediately after placing an element.
- Verification: 20 JavaScript tests; browser checks for fixed dimensions during typing, vertical fitting on exit, initial typing focus, empty-row Backspace/X deletion, mouse insertion, multiline row spacing, no description control, empty-element cleanup, idea placeholder cleanup, and front/end caret edits after resizing. Screenshot: `docs/milestone-5.2-editing.jpg`.

## 0.5.1 — 2026-11-09 — Edge Panning and Text-Aligned Placement

- Dragging objects/selections near a canvas edge now pans continuously, with a gradual speed increase toward the edge. The dragged content keeps its grab point as the viewport moves, including at different zoom levels. Resize, connection, marquee, and toolbar drags also support edge panning.
- Panning stops on release, cancellation, blur, teardown, or unavailable canvas access; toolbar/dialog/control regions do not trigger it.
- Tool placement now aligns the pointer with the initial text/caret location rather than the element’s top-left corner. Shape/idea text uses its centered position; text/note/task/file boxes use their text inset. Both toolbar drops and click placement use the same anchor.
- Placement previews show the matching surface, sample text, and a caret at the pointer. Toolbar drag previews now remain visible during dragging.
- Verification: **19 JavaScript tests passed**, compilation with warnings as errors and syntax checks passed. Browser checks verified a note dropped at (400, 350) rendered text at x≈399.5, center y≈349.4; edge dragging changed the viewport and stopped after release; a zoomed preview caret remained at the pointer. Existing collaboration protocols and storage are unchanged.
- Screenshot: `docs/milestone-5.1-placement.jpg`.

## 0.5.0 — 2026-11-09 — Milestone 5: Advanced Canvas and Workflow

### Added

- Drag a creation tool onto the canvas, with click-to-place retained. Click inside to type; drag an object’s border to move, with matching cursors.
- Drag-to-connect with an in-progress curve. Automatic endpoints align with measured text on plain text/white notes and with actual shape outlines. Selected endpoints can be adjusted and reset to automatic attachment.
- Content fitting for plain text and white notes; explicit Fit to text; 12–72 text sizes for all text-bearing boxes. Manual resizing locks the width for wrapping; cards grow to accommodate content. White notes have a transparent surface so the line reaches the written text.
- Checklist cards with optional titles/descriptions, independent checkboxes, Enter-to-add, drag-to-reorder, keyboard reordering, and item removal. Legacy single-task content and completion display as a single item, with conversion on edit.
- Marquee selection, Ctrl/Command-click selection, persistent Group/Ungroup, multi-object movement/resizing, bulk deletion, duplication with internal connections, Select All, and arrow-key nudging.
- Right-drag panning, eased pointer-anchored wheel zoom, 5% zoom buttons, and an explicit Mouse/Trackpad navigation choice for reliable fine-wheel behavior.
- Named, color-coded live cursors in world coordinates, with server-assigned identity, rate limits, departure handling, and stale-cursor cleanup. Cursor positions are not saved to the board.

### Changed

- Atomic multi-object operations preserve revision checks, deduplication, authorization, and explicit draft recovery. A conflicting or invalid child saves none of the selection.
- Canvas interactions live in `canvas-ui.mjs`; synchronization and recovery remain in `app.mjs` and the collaboration model. RAF rendering, reused SVG paths, cached text anchors, structural sharing, and viewport culling reduce work for larger boards. Group previews use one bounded packet and authorization check per frame instead of one per object.
- Existing element records are prefetched for writes; removed selections use one delete query. Inline file content is unchanged during geometry-only updates.
- Malformed operation envelopes, nested batches, invalid checklist/anchor metadata, and batch attempts to rename an owner’s board are rejected.
- Version is 0.5.0; `:nook`, `Nook`, `NookWeb`, supplied branding, and toolbar order remain intact. New metadata uses existing JSONB storage; existing boards need no destructive migration.

### Verification

- **145 backend tests and 16 JavaScript tests passed**, including atomic rollback/replay, grouping, checklist/anchor persistence, cursor identity/revocation, conflict rebase, shape geometry, fine zoom, and large-board structural sharing.
- Real-session HTTP/WebSocket smoke covers atomic diagrams/groups/checklists and authenticated cursors alongside prior invitation, admission, conflict, replay, and revocation flows.
- Browser: toolbar drag creation, direct typing, 32px text in a white note, content-fit connections, endpoint dragging/reset, checklist title/Enter/completion/reordering, marquee/Ctrl-click, grouping/ungrouping, group movement/resizing, bulk duplicate/delete, nudge, wheel zoom, trackpad pan, named cursors, and competing-text draft recovery.
- A legacy task fixture retained its original text, checked state, and description before conversion; editing preserved its content.
- A 500-object fixture created in **118.6 ms** and moved/grouped atomically in **103.2 ms** on this machine. Browser culling showed 30 of 500 objects initially and 42 after panning. These are local checks, not production benchmarks.
- Restart comparison preserves the playground, a 500-object grouped board, and a converted legacy task. The five original DETS boards retain every original title and element field.
- Source/database backups: `.nook-history/milestone-4-source-before-m5-2026-11-09.zip` and `.nook-history/milestone-4-before-m5-2026-11-09.dump`.
- Screenshots: `docs/milestone-5-canvas.jpg`, `docs/milestone-5-conflict.jpg`.

### Scope

- Milestone 5 and the five requested workflow changes are included. Production hosting, cross-device reachability, horizontal scaling, and production email remain Milestone 6 work.
- Checklists use one revisioned list per card; competing edits to the same list require review. The board remains limited to 2,000 elements and one write coordinator.

## 0.4.0 — 2026-11-06 — Milestone 4: Sharing and Multiplayer

### Added

- Owner-controlled room-code requests with Admit/Decline, session-bound status polling, refresh recovery, ten-minute expiry, and bounded waiting lists. Waiting visitors receive no board content.
- Named, color-coded Presence with server-assigned owner/editor roles and distinct-person counts; multiple tabs share one participant identity. Room shows the participant list and display-name editing.
- Transactional element-revision checks. Independent property changes merge against captured baselines; competing changes and stale deletions require an explicit choice.
- A readable current-board/draft comparison with Use current board, Keep my version, and Keep as a new element for deleted drafts. Unsent text is captured before remote deletion removes its editor.
- Canonical element revisions, authoritative client snapshots, local recovery copies, ordered pending replay, revision-gap resync, and reconnect recovery without forced page reload.

### Changed

- Invitation replacement, Disable sharing, claiming, and deletion invalidate earlier guest admissions through an access epoch. Closing only room-code requests retains already admitted editors.
- Approved guests remain editors; owner controls and existing account/guest lifecycle rules remain enforced. Dashboard privacy labels include approved guests.
- Existing element IDs cannot be overwritten by creation; replacing an attachment requires its current element revision. Recovery copies and baseline fields are omitted from operation broadcasts.
- Application version is 0.4.0; project/module identity remains `nook` / `Nook` / `NookWeb`. Original branding and exact toolbar order are preserved.

### Verification

- **138 backend tests and 11 JavaScript tests passed.** Compilation with warnings treated as errors and JavaScript syntax checks passed.
- Real cookie/CSRF/WebSocket smoke checks: invitation and code-only access, approval isolation, named/grouped Presence, independent-field merges, simultaneous competing writes, reconnect/dedup recovery, durable snapshots, and live revocation.
- Browser checks: room toggle, display name, waiting visitor and Admit action; competing text edits and explicit keep; remote deletion before text debounce and recovery as a new element; synchronization across two app-browser tabs. Chrome automation timed out, so separate-browser identity isolation was verified by real HTTP/WebSocket sessions.
- PostgreSQL restart preserved the acceptance board's content, element revisions, and admission setting. All five original DETS boards still match every original title and element field.
- Pre-upgrade source and PostgreSQL backups: `.nook-history/milestone-3-source-before-m4-2026-11-06.zip` and `.nook-history/milestone-3-before-m4-2026-11-06.dump`.
- Browser evidence: `docs/milestone-4-conflict.jpg` and `docs/milestone-4-room.jpg`.

### Scope

- Local multiplayer is complete for this milestone. Cross-device hosting, horizontal scaling, production email, and deployment remain Milestone 6 work.
- Multi-selection, grouping, advanced geometry, and larger-board performance remain Milestone 5. User-proposed quality-of-life changes remain deferred.

## 0.3.0 — 2026-11-06 — Milestone 3: Guest Boards and Accounts

### Added

- Phoenix 1.8's generated authentication context, user/session token schemas, email confirmation and magic-link recovery/login, optional password authentication, and account settings. PBKDF2 handles password hashing on Windows.
- Nook-styled account pages and dashboard for private permanent boards, with create/reopen/rename/delete/restore actions.
- Signed, encrypted browser sessions with random guest identity; user sessions are checked against the database on board access and mutation.
- Configurable seven-day inactivity expiry for guest boards, activity renewal only after authorized use, a periodic expiry worker, and visible guest/permanent lifetime information.
- Creator-only guest-board claiming after verified sign-in, preserving contents and resetting sharing to private permanent ownership.
- Random 256-bit invitation secrets, hashed server-side grants, invitation rotation/disable actions, and immediate live revocation. Separate one-use recovery secrets preserve access to legacy boards.
- Private local legacy recovery files, a pre-change source archive, and a PostgreSQL dump. Nine pre-account boards retained.
- Real-session HTTP/WebSocket smoke checks and tests for ownership, expiry, claims, recovery, forged events, and already-connected sessions losing permission.

### Changed

- Room codes and plain board URLs identify boards but no longer grant access. A new visitor needs an owner-created invitation; eligible creators/owners can reopen directly.
- Permission checks cover reads, lifecycle actions, channel joins, writes, previews, and outbound board events. Only owners can rename a board or manage sharing.
- Authentication preserves guest creator identity and the requested board across session renewal. Local URLs consistently use `127.0.0.1` to retain the same browser identity through confirmation.
- Account emails use the development preview inbox. External delivery remains part of deployment work.
- Deleted/expired records are retained; this milestone does not irreversibly purge board contents.
- Ecto updated from 3.14.2 to 3.14.3, resolving the advisory reported during dependency installation.
- Production runtime now requires an explicit secret and database URL. Version advanced to 0.3.0.

### Scope

Milestone 3 only. Quality-of-life ideas remain for a later pass. Richer participant/room admission and conflict UX are tracked under Milestone 4.

### Verification

- 132 backend tests and 5 JavaScript tests passed; warning-free compilation and the real-session HTTP/WebSocket access smoke test passed.
- Browser registration, email confirmation, guest-to-permanent claiming, dashboard reopen, invitation creation/revocation, and logout passed.
- Original legacy content comparison passed; pre-account PostgreSQL/source backups and private one-use recovery links were retained.

## 0.2.0 — 2026-11-02 — Milestone 2: Core Toolbox and Persistence

### Added

- PostgreSQL and Ecto, with separate board/element schemas, migrations, JSONB content, geometry constraints, layer ordering, and stored element revisions.
- Atomic saves under a board row lock, with acknowledgements and PubSub broadcasts following successful commits.
- A read-only DETS import that preserves existing board links and data and skips already-imported boards on reruns.
- Phoenix LiveView pages for the landing page and board shell, LiveView creation/joining events, CSRF/session plumbing, and a lifecycle-managed JavaScript canvas hook.
- Phoenix Tailwind build support while retaining the custom Nook styles and logo asset.
- Rectangle, rounded rectangle, circle, triangle, and diamond choices; a local placement preview; proportional circle resizing.
- Persistent text size and ink color controls, optional task descriptions, and Front/Back layer controls.
- Click-to-place editable file labels with an optional Attach file action; existing uploads remain supported.
- A lightbulb symbol for idea cards.
- Portable, loopback-only PostgreSQL setup/start scripts with generated credentials outside the repository, and an isolated test runner.
- Original project brief, milestone tracking, a baseline source archive, and a second legacy-data copy.

### Changed

- Persistence now uses PostgreSQL rather than DETS. The legacy file is retained rather than deleted or rewritten.
- The toolbar now sits near the top, matching the supplied master prompt; order and Nook branding are preserved.
- Fit-to-board reserves space for the top toolbar. Text cards grow to avoid clipping larger text.
- Task detail and pasted-text changes autosave. Hook destruction cleans up global listeners, sockets, and timers.
- Version advanced from 0.1.0 to 0.2.0.

### Verification

- All five existing DETS boards imported; a second run skipped all five without overwriting them.
- Backend/LiveView tests, JavaScript model tests, two-client WebSocket smoke test, and browser interaction checks. Final counts and evidence are recorded in `docs/milestones.md`.

## 0.1.0 — 2026-10-31 — Initial canvas

- Nook branding, landing page, eight-tool toolbar, local pan/zoom/move/resize/edit interactions, tasks, attachments, connections, autosave, room sharing, and Presence.
- Initial single-node DETS storage and a plain browser-rendered interface. The original milestone plan was not available during this build; PostgreSQL, LiveView, and remaining toolbox requirements were completed in 0.2.0.
# Focused follow-up — Selection and remembered view (November 11, 2026)

- Ctrl/Cmd/Shift-click on written content now leaves the existing selection intact until the canvas selection handler toggles the target. Ordinary clicks still enter editing; grouped selection retains its existing behavior.
- Each board remembers its pan and zoom locally in this browser. Saving is debounced during navigation and flushed when leaving the page. Invalid or unavailable storage falls back to the existing initial view. Camera preferences are not sent to collaborators or added to board history/content.
- Verification: 155 backend and 51 JavaScript tests passed; compilation/format checks and the real multiplayer smoke check passed. Browser checks confirmed Ctrl selection across grouped text and a task title, Shift/Cmd toggling, ordinary title editing, exact pan/zoom restoration after reload, working Show everything, and no browser errors.
- Source backup: .nook-history/before-selection-camera-fix.zip. Evidence: docs/selection-camera-fix-preview.png. No other feature changes or publishing.

# 0.10.0 — Collaborative drawing (November 12, 2026)

- Added Draw alongside Select and Hand, preserving the eight creation tools and their order. The pen stays active across strokes; a native custom color picker and fine 1–24 brush-size slider appear only in Draw mode. A tap creates a dot. Escape cancels an unfinished stroke and returns to Select; choosing a creation tool or Hand leaves Draw. Keyboard creation also exits Draw before focusing the new editor.
- Strokes use rounded SVG paths with sampled input and iterative point simplification. Each finished stroke is one saved board element and one undoable action, with existing reconnect recovery, autosave, selection, position locks, grouping/ungrouping, movement, resizing, duplication, recoloring, and deletion. Stroke editing never creates a text editor. Existing right-drag panning and wheel zoom remain available.
- Added authorized, server-attributed live drawing previews. Active previews are client-throttled, server-throttled, bounded to 128 points, never persisted, cleared at completion/cancellation, and expired locally if a sender disappears. Finished strokes are bounded to 2,048 points and 10,000 units per dimension; a board may contain at most 500 strokes and 100,000 drawing points. Both client and server enforce drawing budgets; other public-launch abuse/storage work remains pending.
- Versioned the changed browser module chain and drawing stylesheet so existing cached modules do not hide the update. Added Draw instructions to Help.
- Verification: 158 backend and 54 JavaScript tests passed (212 total), including malformed strokes, point-budget enforcement, preview validation/throttling, simplification, and stroke undo/redo. Real HTTP/WebSocket smoke checks covered preview fanout and completed-stroke persistence alongside the existing multiplayer suite. Browser checks covered dots, repeated strokes, brush color/size, whole-stroke undo/redo, grouping, movement, resizing, recoloring, Delete/undo, persisted reload, keyboard mode switching, and preserved note editing. Browser error logs were empty.
- Source backup: .nook-history/before-draw-mode.zip. Browser evidence: docs/draw-mode-0.10-preview.png, isolated test board EYOUR56364FTU. Nook remains local; nothing was published.

# 0.10.1 — Drawing assistance and shared colors (November 12, 2026)

- Pausing for 650 ms while holding a drawn line straightens it. Keep holding and move to adjust its endpoint, then release. Saving records the rough sketch and the straightened result as separate actions, so the first Undo restores the sketch and a later Undo removes its creation. Cancellation and pointer loss clear the hold timer and transient preview.
- Added an explicit Clean up shape button for selected strokes, as requested. Recognition covers lines, axis-aligned boxes, triangles, diamonds, ovals, continuous or three-stroke arrows, separate polygon sides, and a four-stroke smiley (outline, two eyes, smile). Cleanup is conservative and optional; unrecognized sketches are left alone. IDs, colors, width, groups, and existing attachments remain intact. Cleanup and its undo use validated geometry patches shared with collaborators.
- Added Group strokes inside Draw. With it enabled, left-drag a box to highlight and automatically group fully enclosed, unlocked strokes. Normal pen drawing remains the default; ordinary Select mode retains its existing selection behavior.
- Added the same 60 standard color swatches to drawing and the existing color controls for fills, icons, strokes, and text. The original quick colors, custom wheel, recents, and contrast feedback remain available.
- Verification: 159 backend and 59 JavaScript tests passed (218 total). Tests cover hold timing/cancellation, endpoint adjustment without losing the rough path, recognition including multi-stroke faces/arrows, cleanup-first undo, grouping containment, palette values, persisted geometry patches and malformed-point rejection. Real HTTP/WebSocket smoke checks verify cleanup/restoration fanout and saving alongside existing multiplayer behavior. Browser checks on isolated board L4EMC5BVBQFN4 confirmed four-side box grouping, cleanup, exact restoration of the rough paths without deletion, redo, shared fill/text colors, and the drawing palette. Hold timing itself was verified with automated tests.
- Backup: .nook-history/before-drawing-cleanup.zip. Evidence: docs/drawing-assist-0.10.1-preview.png. Nook remains local; no publication.

# 0.11.0 — Google sign-in and Render preparation (November 12, 2026)

- First Render launch exposed a production database URL without an explicit port inheriting the local 55432 setting. Production now defaults to PostgreSQL's 5432 and respects explicit URL ports; both cases have regression coverage. Direct verified-TLS Neon connectivity passed before redeployment.

- Added server-side Google OpenID Connect through Assent, with session-bound state, a five-minute flow lifetime, PKCE, random nonce, verified HTTPS requests, and validated token signature/issuer/audience/expiry/nonce. Access and ID tokens are not persisted or logged. Only basic identity/email access is requested. Google's official sign-in logo is served locally.
- Added a unique Google subject to existing Nook users. Google creates a confirmed account without sending email or requiring a Nook password. Matching email alone never links an existing account; linking requires recent sign-in to the same confirmed Nook account. Session renewal preserves guest-board ownership. Remember-me cookies are secure in production.
- Added `NOOK_AUTH_MODE=google`: Google-only login, registration and settings screens work without SMTP credentials; email/password routes are disabled in that mode. Local development retains previous account flows by default. Google callback configuration is fixed to the production HTTPS hostname.
- Added bounded production traffic limits for board creation, writes, callbacks and channel messages, plus an 8 MB per-board serialized-content budget. Brief write throttling keeps local drafts and retries instead of opening a conflict dialog. Existing drawing limits remain in place.
- Added free Render/Neon configuration, Linux build/start scripts, database migration on start, and a liveness-only host probe. Smaller connection pools, a longer idle interval and configurable expiry sweep reduce idle database work. The current Render JSON schema validates the Blueprint. A sanitized standalone source checkout excludes local board data, recovery files, private settings, and generated builds.
- Verification: 170 backend and 59 JavaScript tests passed (229 total), including forged ID tokens, wrong issuer/audience/nonce/expiry, callback state/expiry/replay, safe account linking, Google-only pages, rate windows, board-creation limits and atomic storage-limit rejection. Local production releases built and booted successfully in both email mode and Google-only mode with SMTP settings absent; no real Google login or public deployment has been verified yet. Real HTTP/WebSocket multiplayer, reconnect and collaborative Undo/Redo smoke checks also passed. The five original boards retain all original fields and titles.
- Cloud setup: connected Render workspace confirmed by the user; a separate free Neon Nook project was created. Render publication remains pending an app-source GitHub repository and real Google OAuth credentials. No local board/account data was uploaded. See docs/render-launch.md for the remaining setup and acceptance checks.
- Backup: .nook-history/before-google-render.zip. Deployment source: .nook-history/deploy-source. No public Nook URL is live yet.

