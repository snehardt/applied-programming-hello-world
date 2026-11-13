. "$PSScriptRoot\environment.ps1"
Invoke-NookMix local.hex --force
Invoke-NookMix local.rebar --force
Invoke-NookMix deps.get
& "$PSScriptRoot\database.ps1" -Install
. "$PSScriptRoot\environment.ps1"
Invoke-NookMix ecto.create
Invoke-NookMix ecto.migrate
Invoke-NookMix nook.import_legacy
Invoke-NookMix nook.upgrade_access
& "$PSScriptRoot\assets.ps1"
Write-Host 'Ready. Run .\scripts\start.ps1 to open Nook on port 4000.'
