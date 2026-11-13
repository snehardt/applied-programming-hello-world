. "$PSScriptRoot\environment.ps1"
Copy-Item deps/phoenix/priv/static/phoenix.mjs priv/static/assets/phoenix.mjs -Force
Copy-Item deps/phoenix_html/priv/static/phoenix_html.js priv/static/assets/phoenix_html.js -Force
Copy-Item deps/phoenix_live_view/priv/static/phoenix_live_view.esm.js priv/static/assets/phoenix_live_view.esm.js -Force
Invoke-NookMix tailwind.install --if-missing
Invoke-NookMix tailwind nook
