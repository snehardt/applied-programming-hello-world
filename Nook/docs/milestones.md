# Nook development progress

The supplied master prompt defines the milestone order. The product remains **Nook** (`:nook`, `Nook`, `NookWeb`). Each development pass is recorded in `CHANGELOG.md`; the package version identifies the current milestone release.

| Milestone | Status | Notes |
| --- | --- | --- |
| 1. Foundation and Canvas Prototype | Complete | Initial interactive canvas shipped October 31; PostgreSQL/Ecto and LiveView foundation gaps closed November 2. |
| 2. Core Toolbox and Persistence | Complete | Toolbox, editing/deletion, five shapes, resizing, consistent placement, and PostgreSQL persistence. |
| 3. Guest Boards and Accounts | Complete | Phoenix accounts, dashboard, permanent ownership, creator-only claiming, seven-day guest inactivity expiry, and server-enforced access. |
| 4. Sharing and Multiplayer | Complete | Invitations, owner-approved room-code joining, named/grouped Presence, concurrent-edit conflict recovery, and reconnect replay. |
| 5. Connections and Advanced Canvas Features | Complete | Content-aware drag connections, checklist cards, direct editing/drag placement, marquee selection, grouping, smooth navigation, live cursors, and larger-board improvements. |
| 6. Polish and Deployment | Local work complete; publishing deferred by owner | Expanded tests, recovery/loading feedback, accessibility polish, production configuration, verified backups and a locally built release. No online hosting. |

## Milestone 2 acceptance

- [x] All basic element types: text, note, shape, task, file label, idea; existing connections retained.
- [x] Editable/deletable elements, task descriptions, text styles, and layer controls.
- [x] Rectangle, rounded rectangle, circle, triangle, diamond.
- [x] Resize handles, proportional circles, correct world coordinates under zoom/pan.
- [x] Durable PostgreSQL board/element records with validated, atomic writes.
- [x] Exact toolbar order, top placement, active state, placement preview, Escape cancellation.
- [x] Existing boards imported without overwriting newer database content.
- [x] Refresh recovery and preserved multiplayer behavior.

## Migration record — November 2, 2026

- Before changes: source archived to `.nook-history/milestone-1-source-2026-11-02.zip`.
- Before import: legacy store copied to `.nook-history/boards-before-postgres-2026-11-02.dets`.
- First import: **5 boards imported**. Second import: **0 imported, 5 skipped**.
- Original `data/boards.dets` retained. Current writes go to PostgreSQL.
- Local PostgreSQL binaries, database files, and credentials live under `%LOCALAPPDATA%\Nook`, outside the source tree.

## Validation

- `scripts/test.ps1`: 10 backend/LiveView tests and 5 JavaScript tests passed against PostgreSQL.
- `node scripts/smoke.mjs`: two real WebSocket clients, bidirectional operations, saved snapshot recovery, and unknown-room rejection passed.
- `mix run scripts/verify_legacy.exs`: every original element field and title across all five legacy boards matched PostgreSQL. SHA-256 confirmed the original DETS file is identical to its pre-migration copy.
- Restarted both PostgreSQL and Phoenix: the acceptance board's complete JSON snapshot was unchanged.
- Browser/REST: a circle resized at 69% zoom retained equal width and height in PostgreSQL; text size/color, task details, uploaded attachment, and board title persisted.
- Browser: LiveView board creation; shape chooser/placement/editing; text size/color; task descriptions; file-label attachment; duplicate/delete; refresh recovery. Visual evidence is saved in `docs/milestone-2-preview.jpg` after final verification.

## Architectural boundary

LiveView owns the pages, account/dashboard flow, and board lifecycle events. Its whiteboard hook owns the frequently changing canvas DOM (`phx-update="ignore"`), keeping pointer motion local. Channels carry durable operations and lightweight drag previews. Ecto stores shared geometry separately from type-specific JSONB content. Milestone 3 adds caller identity and current permissions to every board entry point; Milestone 4 adds element-revision checks and explicit conflict recovery.

## Milestone 3 acceptance — November 6, 2026

- [x] Standard Phoenix 1.8 generated email confirmation/login, optional passwords, account settings, and revocable sessions.
- [x] Development preview inbox for local confirmation/login emails; no external mail is sent by this build.
- [x] A personal dashboard with permanent board creation, reopening, renaming, soft deletion, and restoration.
- [x] Quick boards with configurable seven-day inactivity expiry and explicit lifetime information.
- [x] Creator-only, unexpired guest-board claiming after account confirmation; content survives, old invitations are revoked.
- [x] Private permanent ownership plus owner-controlled, hashed editing invitations. Room codes alone confer no access.
- [x] Authorization on HTTP, LiveView events, channel joins, durable writes, previews, and outbound broadcasts; connected guests lose access on revocation.
- [x] Legacy data preserved and one-use creator recovery links exported locally.
- [x] Account/login/claim/dashboard/reopen/logout exercised in the browser, with a saved dashboard preview.

### Migration and verification

- Pre-upgrade source archive: `.nook-history/milestone-2-source-2026-11-06.zip`.
- Pre-upgrade PostgreSQL dump: `.nook-history/milestone-2-before-accounts-2026-11-06.dump`.
- **9 pre-account boards preserved**, with recovery links in `.nook-history/legacy-board-recovery.md` and JSON. Reruns prepare zero additional links and preserve existing recovery credentials.
- Backend tests cover generated authentication plus ownership isolation, expired reads/writes, claiming, replay/atomicity, one-use recovery, dashboard actions, and socket revocation. Canvas model tests remain in place.
- Real-session smoke test covers CSRF rejection, code-only HTTP/channel denial, secure invitation redemption, two-client editing, persisted snapshots, and immediate live revocation.
- Browser: quick-board creation/editing, registration, preview-inbox confirmation, preserved creator identity, permanent claim, dashboard reopen, owner invitation creation/disabling, and logout.
- Screenshot: `docs/milestone-3-dashboard.jpg`.
- Final checks: **132 backend tests, 0 failures; 5 JavaScript tests passed; real HTTP/WebSocket access smoke test passed; compile with warnings treated as errors passed.** The five original DETS boards still match their original fields and titles after the account migration.

Quality-of-life ideas remain deferred for a later user-directed pass.

## Milestone 4 acceptance — November 6, 2026

- [x] Invitation links and owner-approved room-code joining preserve the existing access model.
- [x] New visitors wait without seeing board data; current owners can admit/decline. Requests expire, resume after refresh, and cannot be polled or approved by another guest.
- [x] Room shows display names, colors, owner/editor roles, grouped tabs, and a distinct-person count.
- [x] Phoenix Channels/PubSub synchronize committed changes; lightweight movement previews remain local-first.
- [x] Same-property conflicts and stale deletions preserve local drafts for a choice. Independent property edits merge, and attachment replacements require a revision.
- [x] Remote deletion during typing captures the draft and offers recovery as a new element.
- [x] Rejoin snapshots and deduplicated acknowledgements preserve newer collaborator changes while pending operations replay.
- [x] Invitation rotation, disabling sharing, claiming, deletion, and expiry continue enforcing access on connected clients.
- [x] Existing boards and original visual identity are preserved; source/database backups are recorded in the changelog.

Validation: **138 backend tests, 11 JavaScript tests, compile with warnings as errors, JavaScript syntax checks, real-session multiplayer smoke, PostgreSQL restart comparison, and five-board legacy preservation passed.** Browser checks verified admission controls, live synchronization, conflict keep, and deleted-draft recovery across two app-browser tabs. Chrome automation was unavailable; isolated browser identities were exercised with separate HTTP sessions and real WebSockets. Screenshots: `milestone-4-room.jpg`, `milestone-4-conflict.jpg`.

The server currently serializes writes through one coordinator. Larger-board optimization belongs to Milestone 5; production hosting/scaling belongs to Milestone 6. Board-title edits remain owner-only, with the last accepted title retained.

## Milestone 5 acceptance — November 9, 2026

- [x] Drag-to-connect, live curve previews, automatic text-center/shape-outline attachment, endpoint adjustment and reset.
- [x] Plain text and white-note fitting, manual-width wrapping, Fit to text, and adjustable text size inside boxes.
- [x] Multi-item task checklists with optional title/description, completion, Enter-to-add, item removal and drag/keyboard reordering.
- [x] Legacy task content and completion remain visible and convert only on interaction.
- [x] Drag-from-toolbar creation plus retained click placement; center-to-type and border-to-move cursors.
- [x] Empty-space marquee, Ctrl/Command-click, bulk move/resize/delete/duplicate, persistent groups, and keyboard shortcuts.
- [x] Right-drag pan, fine animated pointer-anchored zoom, and explicit Mouse/Trackpad modes.
- [x] Authorized named/color-coded live cursors, independent viewport coordinates, departure/stale cleanup.
- [x] Atomic batches retain revision/conflict/replay safeguards and never partially move a selection.
- [x] RAF-coalesced rendering, unchanged-node/path reuse, text-anchor caching, structural sharing, viewport culling, and reduced persistence queries.
- [x] Source/database backups, updated usage instructions, and original branding/toolbar order preserved.

Validation: **145 backend tests and 16 JavaScript tests passed**. Real HTTP/WebSocket sessions verify batches, checklists, groups, cursors, and all previous access/conflict flows. Browser checks cover drag placement, typing, text sizing/fitting, connections/endpoints, checklists/reordering, selection/group operations, zoom/pan, cursor alignment and conflict review. A 500-object fixture showed viewport culling (30 visible initially; 42 after panning); local creation took 118.6 ms and an atomic move/group took 103.2 ms. Restart snapshots cover the playground, grouped load fixture, and converted task; original five-board legacy comparison passes. Screenshots: `milestone-5-canvas.jpg`, `milestone-5-conflict.jpg`.

New fields use existing JSONB storage. Production deployment and scale remain Milestone 6; checklist changes are revisioned at card-list granularity, with explicit review for competing list edits.

### Milestone 5 follow-up — 0.5.1

Edge auto-panning and text-aligned tool placement are included. Pointer-anchored previews are shared by toolbar drag/drop and click placement. The follow-up passes 19 JavaScript tests and browser checks for placement alignment, zoomed previews, edge movement, and stopping after release.

### Editing corrections — 0.5.2

Boxes remain fixed while typing and fit only vertically on editor/card exit. Written text is clickable; unused object space drags. Placement and single-object manipulation focus the editor. Checklists have wrapping, spaced rows, Backspace/X removal, a clickable insertion gap, and no description field. Empty plain text/ideas are removed on exit; completed cards hide placeholders. Browser checks cover these flows, stable dimensions, immediate typing, and editing both ends after manual resizing.

### Live text growth — 0.5.3

Notes and text now wrap and grow downward while typing, with the caret kept in view. New text defaults to 360px/18px, and new notes to 320px/16px. Existing geometry and font choices are preserved. Heights autosave with content and may shrink on exit; checklist behavior is unchanged. JavaScript regression checks: 22 passed.

### Content fits without scrollbars — 0.5.4

Canvas items grow to fit content, including checklist cards, ideas, shapes and file labels. Internal scroll areas are removed. This is the ongoing canvas interaction rule. Verified JavaScript tests and browser checklist/idea growth.

### Text-aligned border connections and routing — 0.5.5

Connections meet box borders at the text center and route around other items using rounded bends. Automatic text/white-note widths compact on exit; manual widths are preserved. Verified with 24 JavaScript tests and browser creation, persistence and obstacle movement.

### Preserve shape sizes — 0.5.6

Shapes are excluded from automatic content sizing. Their dimensions remain as chosen through editing, appearance changes and reload. Manual resizing remains available; text compaction and connection routing are unchanged.

## Milestone 6 acceptance — November 9, 2026

- [x] Expand automated coverage for save/load states, production settings, health probes, browser security headers, accessible recovery controls, error pages and failed email delivery.
- [x] Persistent board loading/retry UI, safe initial loading controls, offline draft notice, accurate reconnect/save state and retryable registration delivery errors.
- [x] Keyboard tool placement, named dialogs, skip link, visible keyboard focus, reduced-motion zoom/CSS and compact toolbar styling.
- [x] Keep logo/order/purple identity and all requested canvas sizing/connection behavior.
- [x] Real multi-session WebSocket checks including simultaneous edits, server disconnect/rejoin, independent offline replay, replay deduplication and four-visitor atomic fanout.
- [x] Secure runtime production settings, explicit origins/HTTPS, secure cookies, verified database/SMTP TLS, configurable mail sender, no development inbox and generic health probes.
- [x] Build and boot-check a local production release with HTTP serving disabled; separate migration entry point.
- [x] Source/database backups and an isolated backup restoration with matching record counts; original five-board legacy comparison passes.
- [x] Local operating, recovery and future deployment instructions in `docs/production.md`.
- [ ] Publish/host Nook — deliberately deferred by the owner. Domain/provider configuration and real hosted-environment checks wait for that decision.

Verification: **151 backend tests, 26 JavaScript tests, real HTTP/WebSocket smoke, warnings-as-errors compilation, production release build/HTTP-disabled boot, backup restore and legacy preservation passed.** Browser recovery test stopped Phoenix, saved an offline draft, restarted, observed automatic sync and retained the text after reload. Desktop and 720px toolbar checks passed. Remaining usability feedback stays open; this milestone is not a claim that every workflow is final or that public infrastructure has been tested.

## Approved usability pass — 0.7.0

All eight approved changes are implemented with the final stable-sizing correction. See `docs/usability-pass.md`. Verification: 154 backend tests, 37 JavaScript tests, real HTTP/WebSocket Undo/Redo and multiplayer checks, browser interaction/reload/compact-layout checks, legacy preservation and local release preparation. Existing milestone history above records the earlier behavior; 0.7 rules supersede automatic shrinking/compaction and post-move typing. Publishing remains deferred.

## Second usability review — 0.8.0

The seven reviewed issues are fixed: safe Hand mode, visible-word plain-text hit areas, short/contextual selection options, refreshed/offline history, local recent boards/naming, guided connections and controlled growth/shape fitting. Verification: 154 backend tests, 43 JavaScript tests, browser workflows, real multiplayer/Undo/Redo smoke, legacy preservation and local release/HTTP-disabled boot. See `docs/usability-0.8.md`. New feature ideas remain deferred in `docs/backlog.md`; hosting remains deferred.

## 0.9.0 usability additions

Toolbar collapse, shape replacement, shared colors, Icons, optional alignment snapping, and position locking are implemented. See visual-tools-0.9.md. Free drawing and hosting remain deferred.

Verification: 155 backend tests, 46 JavaScript tests, real WebSocket visual metadata/multiplayer/history smoke, browser interaction and refresh checks, five legacy boards preserved, and 0.9.0 local release build/HTTP-disabled boot passed.

## 0.9.2 workspace organization

Standing instructions/board details moved into Help; creation tools, navigation and selection actions dock to edges; only Colors, Delete and More options appear on initial selection. Right-click opens the advanced options. See workspace-layout-0.9.2.md.

## 0.9.3 item-local controls and review

Select underneath restored to primary actions. Selection controls follow the item/group above its bounds with viewport-safe fallback. Navigation walkthrough and remaining critiques are recorded in usability-review-0.9.3.md. Verification: 155 backend and 48 JavaScript tests, plus browser interaction and narrow-layout checks.

## 0.9.4 creation mode and overlap preview

Hand-to-creation switching and hover/focus overlap previews are implemented. Centered item controls are preserved; neighbor-avoidance was excluded by the owner. See interaction-fixes-0.9.4.md.

## 0.9.5 dragging and quick creation

Shape-style blank-space dragging for all item types, click-to-edit, hover/focus shape/icon choices, and double-click empty canvas text creation are implemented. See drag-and-choices-0.9.5.md.

## 0.9.6 direct reveal and movement

On-canvas overlap outlines replace the selection list; covers stay locally hidden through edits until restored. Side move grips removed. Verification and usage are in reveal-mode-0.9.6.md.
