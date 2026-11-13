# Nook

A simple, collaborative space to bring ideas together.

Milestone 5 adds direct canvas editing, drag-to-connect, checklist cards, multi-selection/grouping, smooth navigation, and live cursors to the Phoenix LiveView/PostgreSQL whiteboard. Existing account, invitation, and draft-recovery features remain available. The Mix application is `:nook`; application modules live under `Nook`, and web modules under `NookWeb`. See [CHANGELOG.md](CHANGELOG.md) for changes and [docs/milestones.md](docs/milestones.md) for progress.

## Google sign-in and Render

See [the launch guide](docs/render-launch.md) for Google-only accounts, the free Render/Neon setup, required secrets, and deployment validation. Existing local email/password flows remain available by default.

## Run locally

Requires Elixir 1.18+, Erlang/OTP 27+, and PostgreSQL. The PowerShell scripts recognize this workspace's per-user Elixir installation and do not change your permanent PATH. First-time setup installs an isolated PostgreSQL 17.6 runtime from the official EDB binary distribution under `%LOCALAPPDATA%\Nook`, creates and migrates the database, imports existing boards, and builds the assets. It does not install a Windows service or change an existing PostgreSQL installation.

```powershell
.\scripts\setup.ps1
.\scripts\start.ps1
```

Open [Nook locally](http://127.0.0.1:4000). Setup has already been run on this computer; normally you only need `start.ps1`. Stop Phoenix with Ctrl+C. The database stays running between app sessions; `scripts/database.ps1 -Stop` stops this project's database when needed.

On macOS/Linux or with an existing PostgreSQL installation, configure `DATABASE_URL` and run:

```sh
mix local.hex --force
mix local.rebar --force
mix deps.get
mix ecto.create
mix ecto.migrate
mix nook.import_legacy
mix nook.upgrade_access
cp deps/phoenix/priv/static/phoenix.mjs priv/static/assets/phoenix.mjs
cp deps/phoenix_html/priv/static/phoenix_html.js priv/static/assets/phoenix_html.js
cp deps/phoenix_live_view/priv/static/phoenix_live_view.esm.js priv/static/assets/phoenix_live_view.esm.js
mix tailwind.install --if-missing
mix tailwind nook
mix phx.server
```

Quick boards need no account. Phoenix, LiveView, Phoenix HTML, and Tailwind come from Mix dependencies; there is no Node package installation. Tailwind omits Preflight to preserve the canvas styles. Interface fonts have local fallbacks. Run `scripts/assets.ps1` after changing Tailwind classes or updating browser-client dependencies. Restart `start.ps1` after Elixir changes. On Windows, Mix copies `priv` into the build; run `mix compile` (or restart the app) and refresh after editing static assets.

## Accounts and board lifetime

- **Create account:** register an email, then confirm with the emailed link. This uses the installed Phoenix 1.8 authentication generator. Email links can also be used to sign in/recover access; passwords are optional and can be set in Settings after confirmation. Login sessions are revocable, and logout disconnects their live sockets.
- **Local email:** this development build keeps confirmation and login messages in [the preview inbox](http://127.0.0.1:4000/dev/mailbox). It does **not** send them to an external email provider. The inbox route is development-only; production email delivery belongs to deployment configuration. Use the printed `127.0.0.1:4000` address; local `localhost` requests redirect there so guest identity survives email confirmation.
- **My boards:** after signing in, create permanent boards, reopen and rename them, and move them to Deleted boards. Restore is available from the Deleted boards section. Permanent boards are private until their owner invites someone or approves a room request.
- **Quick boards:** one click, no account. They expire after **seven days of inactivity**, configurable through `:guest_inactivity_days`. Authorized opening and committed edits extend the deadline; unauthorized requests do not. Every read/write checks expiry, and a periodic worker closes connected expired boards. Expiration and deletion deny access while retaining database records; this milestone does not permanently purge content.
- **Save permanently:** the creator's browser can claim an unexpired quick board after registering/signing in. The `/save/:code` flow preserves browser identity and returns to the same board after login. Invitees cannot take ownership. Claiming preserves content and revokes previous invitations, making the board private under its new owner.
- **Invitations:** an owner/creator can create or replace an editing invitation, or disable sharing. Tokens are random 256-bit secrets. Hashes validate access; an encrypted copy supports owner-only reuse of the same invitation. Redeeming a link grants that browser access. Replacing/disabling the link revokes existing grants and live connections. **A room code alone is not authorization:** existing members reopen immediately; new visitors can request access when the owner opens room-code requests.
- **Room-code joining:** open Room → Allow room-code requests. Visitors enter the code and a display name on the landing page; the owner sees waiting requests and chooses Admit or Decline. Waiting visitors cannot read the canvas. Requests expire after ten minutes, are bound to the requesting browser, and resume after a landing-page refresh. Closing requests cancels the waiting list without ejecting admitted editors. Disable sharing revokes all guest grants and closes requests; replacing an invitation or claiming a quick board also invalidates older guest access and pending requests.
- Guest ownership is bound to a random identity in the encrypted browser session, not a client-supplied user ID. HTTP, LiveView events, channel joins, edits, previews, and outbound board broadcasts all enforce current permissions. User sessions are revalidated against the database, including after a socket was opened.

## Recovering boards from before accounts

The upgrade preserves old boards and generates one-use creator recovery links in **`.nook-history/legacy-board-recovery.md`** (also JSON). Open a link in your normal browser, then register/sign in and save the board permanently. These links receive a fresh seven-day inactivity window when prepared. The old board codes still identify the same data, but codes alone no longer grant access.

`start.ps1` and `setup.ps1` run the repeatable `mix nook.upgrade_access` task. It only prepares newly imported legacy boards, preserves previously generated links, and does not rotate them on each startup. Source and PostgreSQL backups from before this upgrade are retained in `.nook-history/`.

## Use the board

- Create a quick board from the landing page, or join with a room code or invitation link.
- Tools appear in this exact order: **Text, Note, Shapes, Task, Connect, File, Idea, Room**.
- The toolbar sits near the top. Shapes opens Rectangle, Rounded rectangle, Circle, Triangle, and Diamond choices. The placement preview follows the pointer; Escape cancels it. Circle resizing preserves its proportions.
- Drag Text, Note, Shapes, Task, File, or Idea from the toolbar onto the board. Click-to-place still works. The pointer aligns with where text will start (or the text center for shapes/ideas), and the preview marks that location. Placement returns to selection mode; Shapes uses the current choice from its shape menu.
- Drag a move grip or unused visible card space to move it; plain-text blank layout space passes through to the canvas; written text stays clickable for editing. Drag its selected bottom-right handle to resize. Selected objects move and resize together, and circles retain their proportions. Holding a drag near the canvas edge automatically pans the viewport; moving closer to the edge increases its speed.
- Click written text to type, or use Tab to focus its text. Drag the remaining object space to move. Newly placed elements and single-object drags focus their editor automatically. Text autosaves after a short typing pause and when editing ends. Text cards support up to 5,000 characters.
- Use Size (12–72) and More options → Text color for text in boxes. Text and notes wrap and expand downward live so new lines stay visible. Widths stay fixed; finishing editing or removing words never shrinks an item. New text boxes start at 360px/18px and notes at 320px/16px. Height stays at its grown size after leaving the editor. Other cards grow to fit content; shapes keep their chosen dimensions. Fit height excludes shapes. Empty plain-text/idea elements disappear when editing ends; placeholders are shown only while editing. Color swatches and Front/Back controls apply to selected elements. Layers, styles, sizes, and content persist.
- Right-drag to pan. Space + drag and middle-drag also work. Left-drag empty space draws a marquee selection; Ctrl/Command-click adds or removes objects. Groups are selected together. Delete/Backspace removes the selection; Ctrl/Command + D duplicates it and its internal connections.
- Choose Select to drag-select or Hand to pan empty space. In Mouse mode, the wheel makes small, animated zoom adjustments around the pointer. The bottom-right +/- buttons make 5% adjustments. Open Navigation settings and choose Trackpad for two-finger panning and pinch (Ctrl-wheel) zoom. Reset and Fit remain available.
- Connect: choose Connect and drag from one object to another; clicking two objects also works. Curves follow movement, resizing, and written text. Connections meet box borders aligned to the written text and take rounded detours around other items; shapes use their rectangle, ellipse, triangle, or diamond outline. Select a connection and drag an endpoint to adjust its attachment; Reset ends restores automatic attachment.
- Task cards have an optional title and up to 100 individually checkable items. Enter adds an item; Shift+Enter adds a line within an item. Backspace on an empty item or its X removes it. + Add task and the gap immediately above it both insert a row. Drag an item’s handle to reorder it, or use Ctrl/Command + Up/Down in its text field. Existing single-task cards display their original content as one item and convert when edited. Checklist changes autosave; competing changes to the same list still require review.
- Group/Ungroup is available in the selection bar and with Ctrl/Command + G / Ctrl/Command + Shift + G. Groups persist across refresh and reconnect. Arrow keys nudge a selection one canvas unit; Shift nudges ten. Ctrl/Command + A selects all when typing is not active.
- File: choose a supported file first, then click to place it. Dragging File from the toolbar retains its drop point while opening the chooser. Dropping supported files directly onto the canvas also imports them. Images, PDFs, text, Markdown, and CSV files under 1 MB are supported; existing file labels retain their Attach file action. Images render inline; other files have download links. Existing uploads are retained. SVG/HTML uploads are excluded.
- Invite provides a simple Copy invitation link action that reuses the current link. Room shows people, names, the room code and owner admission. Additional sharing options include explicit replacement/disabling with a consequence/cancel dialog. Visitors using a room code wait for approval; invitations grant access directly. The header counts distinct people, grouping tabs in the same browser or verified account.

## Persistence and collaboration

Phoenix Channels distribute committed operations to all room members. Group drag previews are sent together in bounded messages at up to about 17 updates/second (up to 100 objects per preview frame); the final position is persisted on release. Presence shows pseudonymous display names, colors, and owner/editor roles without exposing email addresses or authentication identifiers. Other connections show a color-coded cursor and display name in canvas coordinates, even when viewers pan/zoom differently. Cursor updates are ephemeral, rate-limited, hidden on leaving the canvas, and removed on departure or after five seconds without updates. Element revisions reject stale competing edits; property baselines allow independent changes (such as moving a note while someone edits its text) to merge. A competing edit or stale deletion opens a comparison: use the current board or explicitly keep the local version. If an element was deleted, its draft can be kept as a new element. File replacement also checks the element revision. Board titles remain owner-only and use the last accepted title.

`Nook.Boards` validates and serializes operations. `Nook.Boards.Store` uses Ecto transactions and a row lock to commit board and element changes atomically before acknowledging or broadcasting a save. Boards and elements have separate tables; shared geometry, layer ordering, and element revision are columns, while type-specific content is JSONB. Elements have a composite board/id key and a cascading foreign key. The local app coordinates operation broadcasts through one GenServer; horizontal scaling is not implemented; the prepared release retains this single-coordinator architecture. Conflict checks happen inside the same database transaction as each operation. Broadcasts carry canonical element revisions and omit client recovery drafts. Multi-object moves, resizing, grouping, duplication, and deletion use atomic batches: one stale or invalid child rejects the entire action. Keeping selected changes explicitly rebases the whole action; nested batches and owner-only metadata inside a batch are rejected. Checklist items, group membership, fit preferences, and connection anchors use the existing JSONB content column; no destructive schema migration is needed.

Canvas rendering is coalesced with animation frames. Unchanged element records and SVG paths are reused, off-screen elements are hidden with a margin, and optimistic edits share untouched records instead of deep-cloning large boards. Persistence prefetches existing elements and deletes removed selections in one query while retaining atomic transactions. The current board limit remains 2,000 elements; this is a single-coordinator local build, not a claim of production scale.

The development database is `nook_dev`, and isolated tests use `nook_test`, on loopback port **55432**. Database files live at `%LOCALAPPDATA%\Nook\pgdata` (outside OneDrive). Generated local credentials live at `%LOCALAPPDATA%\Nook\database.json`, outside the repository. Back up PostgreSQL with `pg_dump` before moving computers; copying just this source folder does not copy the new database. Set `DATABASE_URL` for another development database; `TEST_DATABASE_URL` separately overrides the test database.

Milestone 1 boards are imported by `mix nook.import_legacy`. Their codes, content, geometry, connections, and uploaded files are preserved. The importer opens `data/boards.dets` read-only, does not overwrite already-imported boards, and can be rerun safely after stopping the old Milestone 1 server. The original DETS file remains untouched. A source archive and an additional DETS copy from before migration are in the Git-ignored `.nook-history/` folder.

Unsaved operations are queued in separate localStorage backups for each tab (with a session pointer for reload recovery) and retried after channel reconnect or page reload. Recent operation IDs prevent duplicate replay after a lost acknowledgement. An authoritative server snapshot is kept separately from optimistic local edits. Rejoining resynchronizes that snapshot before replaying the queue; a lost acknowledgement returns the current snapshot without replaying the old edit. Save status distinguishes saved, saving, disconnected, and conflict states. Pending operations retain the original edited values and a local recovery copy; legacy unversioned pending patches require review rather than being silently rebased. Storage quota failures show a message; keep the tab open until the server confirms the save.

The app binds to loopback by default. Local invitation links work on this computer. Cross-device collaboration requires reachable hosting; production configuration is prepared in Milestone 6, while hosting remains deferred. Production runtime requires `SECRET_KEY_BASE` and `DATABASE_URL`; development never substitutes its known secret in production. This milestone has not been deployed.

## Branding

The original supplied PNG is used directly in both the landing page hero and application header, preserving its proportions and custom lettering. The interface uses dark purple `#210A3B`, light purple `#AD7BFA`, white, and neutral surfaces. The original toolbar reference is retained in `priv/static/assets/toolbar-reference.png`; live controls are accessible HTML buttons with SVG icons.

## Verification

```powershell
.\scripts\test.ps1
# While the Phoenix server is running (requires Node 22+):
node scripts/smoke.mjs
```

The test script prepares `nook_test`, applies migrations, runs ExUnit with the Ecto SQL sandbox, then the JavaScript tests. Backend checks include generated Phoenix account/session tests plus board ownership, expiry, claiming, recovery, forged dashboard events, invitation revocation, and live-channel authorization. The smoke script uses separate HTTP cookie sessions, CSRF-protected requests, short-lived encrypted socket credentials, and multiple real WebSocket clients. It verifies atomic diagrams/groups/checklists, server-authenticated cursor identity, code-only denial, secure invitations, owner approvals, grouped named Presence, competing-write rejection, independent-field merging, reconnect/replay recovery, persistence, and immediate revocation; it creates a small guest test board in the development database.

## Next milestones

The original master prompt is retained in [docs/master-prompt.md](docs/master-prompt.md), using the Nook name. **Milestone 6 local work is complete; publishing is deferred.** Loading/recovery polish, accessibility improvements, expanded collaboration tests, production configuration and locally verified release/backup tools are included. See [production preparation](docs/production.md). Nothing has been hosted online.

Canvas interaction rule: items grow to fit their content and never show internal scrollbars. This applies to notes, text, ideas, shapes, file labels, and checklist cards and rows.

Connections attach to item borders in line with the written text and take rounded detours around other items. Text and notes keep their width and do not shrink on editor exit; additional content can grow them downward. Moving an obstacle updates the connection route.

Shapes are the exception to automatic content sizing: their dimensions stay as chosen unless manually resized. Typing, appearance changes and leaving the editor do not resize shapes.

Milestone 6 adds a persistent retry screen for load failures, a reconnect notice for device-held drafts, named dialogs, visible keyboard focus, a skip link and reduced-motion behavior. Press Enter on Text/Note/Task/File/Idea in the toolbar to place an item at viewport center. For Shapes, choose a shape, then press Enter on the focused canvas. Existing elements remain keyboard reachable via Tab; Escape leaves editing so arrow keys can nudge a selection.

Local release preparation: `scripts/release.ps1` builds without serving/publishing; `scripts/verify-release.ps1` checks an HTTP-disabled boot. `scripts/backup.ps1 -VerifyRestore` backs up and checks restoration in a separate local database. See `docs/production.md` for configuration and launch limitations.

## Usability pass — 0.7

Visible Undo/Redo keeps your last 50 actions in this tab. Same-tab refresh now preserves that history. Ctrl/Command+Z and Shift+Ctrl/Command+Z act on the board outside editors; text editors retain native typing undo. Independent collaborator edits are preserved, and competing edits block reversal with an explanation. Undo waits for an in-flight save while online and also works offline; queued reversals are checked against the current server board on reconnect. Conflict review still clears unsafe history.

Move grips appear on hover/selection, including one for a multi-selection. Moving or resizing leaves the item selected rather than opening its editor. Shapes show a fitting warning while editing an oversized label and never resize automatically. The latest sizing rule overrides earlier compaction behavior: finishing edits or deleting words never shrinks cards.

See [usability behavior and verification](docs/usability-pass.md) for the eight approved changes, the additive reusable-invitation migration, older-link handling and testing scope. Nothing is hosted online.

## Second usability fixes — 0.8

Hand pans over items as well as empty canvas; only Select mode edits/moves items. Plain text captures its visible words and explicit handles, not the unused layout width. More options contains secondary formatting/layer/group controls. History survives a same-tab refresh and supports checked offline reversals. Recents on the home page help reopen boards from this browser without changing access rules.

Connect shows ports, destination feedback and clear step instructions. Growing cards warn about overlaps without moving neighbors; fixed shapes offer an explicit Make text fit command. See [0.8 behavior and checks](docs/usability-0.8.md). [Future ideas](docs/backlog.md) are recorded for a later pass. Nothing is hosted online.

Visual tools and workspace controls: [0.9 guide](docs/visual-tools-0.9.md). Free drawing and publishing remain deferred.

Workspace layout: [0.9.3 guide](docs/workspace-layout-0.9.2.md).

Latest navigation review: [0.9.3 review](docs/usability-review-0.9.3.md).

Latest interaction fixes: [0.9.4 guide](docs/interaction-fixes-0.9.4.md).

Current dragging and quick creation behavior: [0.9.5 guide](docs/drag-and-choices-0.9.5.md). This supersedes the earlier visible-word-only plain-text hit area.

Current covered-item workflow: [0.9.6 reveal guide](docs/reveal-mode-0.9.6.md). This replaces the overlap list and side move grips.

Reveal now restores on deselection: [0.9.7 behavior](docs/reveal-lifetime-0.9.7.md).

Click-to-place tools can be placed over any existing canvas item or control (0.9.10); the underlying item is not activated by the placement click.

Untitled tasks now keep a visible Add a title header, including after blur/reload (0.9.11). Click anywhere in that header to edit it.
