. "$PSScriptRoot\environment.ps1"
& "$PSScriptRoot\database.ps1"
Invoke-NookMix ecto.migrate
Invoke-NookMix nook.upgrade_access
if (!(Test-Path priv/static/assets/phoenix_html.js) -or !(Test-Path priv/static/assets/phoenix_live_view.esm.js) -or !(Test-Path priv/static/assets/tailwind.css)) {
  & "$PSScriptRoot\assets.ps1"
}
Invoke-NookMix phx.server
