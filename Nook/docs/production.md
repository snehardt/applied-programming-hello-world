# Nook production preparation (not deployed)

Current 0.11.0 setup: Google-only authentication can run without SMTP. Use [the Render launch guide](render-launch.md) for the new configuration and remaining public-login checks. The earlier milestone notes below describe the original email-auth release preparation.

Milestone 6 is prepared and verified locally. Nothing here creates a hosting account, opens a public port, provisions a domain, sends external mail, or deploys Nook. Continue using `scripts/start.ps1` for the local app.

## Local checks and release

```powershell
.\scripts\test.ps1
# With the local app running:
node scripts/smoke.mjs
.\scripts\backup.ps1 -VerifyRestore
.\scripts\release.ps1
.\scripts\verify-release.ps1
```

The release script builds assets, compiles production code with warnings as errors, generates the asset manifest and assembles `_build/prod/rel/nook`. The verification script briefly boots that artifact with HTTP serving disabled, dummy mail settings and a read-only database probe. It sends no mail. Production releases are platform-specific: build on the same OS/CPU as the eventual server. This Windows artifact is for local validation.

## Later production configuration

`.env.production.example` documents the settings; it is a reference, not an automatically loaded secrets file. Use a private environment manager. A production boot requires `SECRET_KEY_BASE` (at least 64 random bytes), `DATABASE_URL`, `NOOK_HOST` (hostname only), `MAIL_FROM`, `SMTP_HOST`, `SMTP_USERNAME`, and `SMTP_PASSWORD`. Never reuse the development secret or local database credentials on a public server.

HTTP serving is **disabled** unless `PHX_SERVER=true`. The default bind address stays **127.0.0.1**. Future hosting should put a trusted HTTPS/WebSocket reverse proxy in front of Nook. Only that proxy should reach the application port and set `X-Forwarded-Proto`; do not expose an endpoint trusting forwarded headers directly to the Internet. HTTPS redirects and HSTS are compiled into the production endpoint; session cookies are secure, encrypted, and SameSite Lax. Socket origins are restricted to `https://NOOK_HOST`.

Database connections default to verified TLS. `DATABASE_SSL=false` exists for local isolated validation; use TLS with the correct CA trust in production. SMTP uses authenticated STARTTLS with certificate and hostname verification on port 587 by default. The development inbox is absent from the production router. A real provider, verified sender/domain, delivery checks and password/login email flows on the real HTTPS domain still need validation before launch. No real mail provider was contacted in this milestone.

After taking a database backup, migrations can later be run through the built release (POSIX example):

```sh
bin/nook eval 'Nook.Release.migrate()'
```

Windows release commands use `bin/nook.bat`. Migrations are deliberately separate from startup. Legacy import/recovery tasks are local migration tools, not automatic production startup work. Keep existing recovery files private.

## Operations and recovery

- `GET /health/live` reports process liveness; `GET /health/ready` checks the database with a two-second query timeout. They return only a generic status, with no credentials or board details. In production, use HTTPS/the trusted proxy for probes.
- `scripts/backup.ps1` creates a custom-format PostgreSQL backup and SHA-256 sidecar in ignored `.nook-history/`. Backups contain private boards and account records: copy them to protected storage; do not publish them with the source/release.
- `-VerifyRestore` restores into a newly created local temporary database, compares board/element/user counts, and removes only that temporary database. It never overwrites the source. Stop active editing during the comparison. Custom `DATABASE_URL` restores are intentionally excluded from this helper.
- To recover on another machine, restore the dump into a **new** database with `pg_restore --exit-on-error --no-owner --dbname=NEW_DATABASE BACKUP.dump`, validate its contents, and point a local test instance at it before switching the application. Never use `--clean` against the only live copy.
- A code rollback means using the previous source/release. Back up before database migrations; an older release may not understand a newer schema. This milestone adds no schema migration.
- Monitor failed saves/conflicts, database readiness, disk use/backups, SMTP failures, application crashes, and the expiry worker. Do not log raw invitation/socket/login tokens or database URLs. Browser pages use no-store, no-referrer, restricted resource policies, and disable unused camera/microphone/location access.

## Verification and remaining launch work

Local acceptance: 151 backend tests; 26 JavaScript tests; real HTTP/WebSocket multi-session checks with disconnect/rejoin, independent offline-edit recovery, deduplicated replay, a four-visitor atomic broadcast and concurrent independent edits; PostgreSQL backup/restore comparison; five original legacy boards preserved; production compilation/release assembly and HTTP-disabled boot verification. Browser checks cover keyboard creation, a real stopped-server draft, automatic reconnection and reload persistence, named dialogs, no console errors, branded 404 navigation, and toolbar layout at 720px. Screenshots: `milestone-6-offline.jpg`, `milestone-6-recovered.jpg`.

The project still has the existing 2,000-element board limit and one board coordinator. This work does not claim multi-node scaling, full mobile/touch parity, complete screen-reader operation of visual diagrams, or a WCAG certification. Real cross-device WAN latency, public HTTPS/proxy routing, provider email delivery, monitoring/alert delivery, and production database failover need a later private staging/launch pass after the owner decides Nook is ready. Current interaction feedback remains open for further quality-of-life work.

References: [Phoenix releases](https://hexdocs.pm/phoenix/releases.html), [endpoint configuration](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html), [Swoosh SMTP](https://hexdocs.pm/swoosh/Swoosh.Adapters.SMTP.html).

## 0.7 follow-up

The local release now includes the approved usability pass and one additive `invite_cipher` migration. Run the normal migration step before starting the new release. Invitation hashes still validate redemption; the encrypted copy enables owner-only link reuse and is excluded from snapshots. Keep the endpoint secret stable and protect backups. Old hash-only invitations are not silently replaced. See `usability-pass.md` for current behavior and the updated 154 backend / 37 JavaScript verification counts. Public hosting and real provider delivery remain deferred.

## 0.8 follow-up

Local release includes the second usability review fixes, guarded offline/history continuity and recent-board metadata. No new schema migration. Current checks: 154 backend tests and 43 JavaScript tests, plus browser offline/reconnect/refresh and real multiplayer/Undo/Redo checks. Session history can contain board content and attachments; keep the browser profile private and close the tab/clear storage when appropriate. It is client recovery state, never an authorization mechanism. No public hosting or real email-provider testing was performed.
