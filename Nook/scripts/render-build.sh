#!/usr/bin/env bash
set -euo pipefail
export MIX_ENV=prod
mix local.hex --force
mix local.rebar --force
mix deps.get --only prod
cp deps/phoenix/priv/static/phoenix.mjs priv/static/assets/phoenix.mjs
cp deps/phoenix_html/priv/static/phoenix_html.js priv/static/assets/phoenix_html.js
cp deps/phoenix_live_view/priv/static/phoenix_live_view.esm.js priv/static/assets/phoenix_live_view.esm.js
mix tailwind.install --if-missing
mix tailwind nook --minify
mix compile --warnings-as-errors
mix phx.digest
mix release --overwrite
