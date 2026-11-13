# Nook: Google sign-in and the free Render launch

The 0.11.0 source includes Google OpenID Connect, Google-only account pages, production resource bounds, Linux build/start scripts, and `render.yaml`. The cloud database is a new database; local boards and accounts are not uploaded.

## Source and service

Deploy this project as the root of a dedicated Git repository. Do not push the parent coursework workspace, `.nook-history`, local data, credentials, screenshots of private boards, `_build`, or `deps`.

Use Render's free Elixir web service in Oregon and the external Neon database. Do not create Render's expiring free database. Commands:

- Build: `bash scripts/render-build.sh`
- Start: `bash scripts/render-start.sh`
- Health: `/health/live`

The start script runs Ecto migrations against the configured database before starting the app. Never point deployment at the local database. Production uses verified database TLS, secure cookies, an HTTPS origin, and the fixed Google callback below.

## Google Cloud setup

1. Create/select a Google Cloud project named Nook. Billing is not required for basic Google sign-in.
2. Under Google Auth Platform, configure Branding (Nook and your support/contact address) and an External audience. Only basic identity/email access is needed; Nook does not request Gmail, Drive, or calendar permissions.
3. Create an OAuth client of type **Web application**, named Nook web.
4. Add the exact authorized redirect URI: `https://YOUR-RENDER-HOST/auth/google/callback`. The hostname must match the actual service hostname returned by Render. For local development, separately allow `http://127.0.0.1:4000/auth/google/callback`.
5. If Google leaves the app in Testing, add the intended test users. Complete Google's publishing/verification steps as applicable before offering it to everyone.
6. Enter the client ID and secret directly into Render environment variables or a protected local secret file for the deployment process. Never commit them or paste the secret in chat.

## Required Render configuration

`render.yaml` declares non-secret settings and prompts for `DATABASE_URL`, `GOOGLE_CLIENT_ID`, and `GOOGLE_CLIENT_SECRET`. `SECRET_KEY_BASE` must be generated securely once and kept stable. With `NOOK_AUTH_MODE=google`, SMTP credentials are not required and email/password account forms are disabled. Local development defaults to the previous email/password flows and can optionally enable Google with the same Google environment variables.

The callback is derived from `NOOK_HOST`, or Render's `RENDER_EXTERNAL_HOSTNAME` when `NOOK_HOST` is absent. An explicit `GOOGLE_REDIRECT_URI` must use that same HTTPS host in production. Bind to `0.0.0.0`, use Render's supplied `PORT`, and set `PHX_SERVER=true`.

Two database connections, a longer idle-ping interval, an hourly expiry sweep, and the liveness-only hosting probe reduce unnecessary work on the free database. Actual compute/storage/network consumption must still be monitored. Free services have startup delays and usage limits.

## Identity safety

Google callbacks use one-time session flow state, a five-minute lifetime, PKCE and a cryptographically random nonce. Assent verifies token signatures, issuer, audience, expiry and nonce; tests include forged tokens. Provider tokens are never stored. The stable Google subject identifies a Nook account. An existing account is not automatically linked just because an email matches; connecting one requires recent authentication to that same confirmed Nook account. Signing in preserves guest-board ownership through session renewal.

## Before calling the launch complete

- Run all tests, the real multiplayer smoke check, production release checks, and legacy-board preservation checks.
- Verify the chosen repository contains only sanitized Nook source.
- Validate the Render configuration against the current schema and review the deployment plan.
- Set real Google credentials and the production database URL securely.
- Verify production HTTPS, real Google sign-in/logout, board saving after reload, guest-board claiming, invitations and two-client multiplayer.
- Inspect deploy/runtime logs and verify no credentials or Google tokens appear.

At source-preparation time, no public deployment or real Google login has been verified. Refer to CHANGELOG.md for the latest completed checks rather than treating prepared infrastructure as a live application.

References: [Google OIDC](https://developers.google.com/identity/openid-connect/openid-connect), [Assent](https://hexdocs.pm/assent/0.3.2/Assent.Strategy.OIDC.html), [Render Phoenix deployment](https://render.com/docs/deploy-phoenix), [Render free limits](https://render.com/docs/free), [Neon free limits](https://neon.com/pricing).
