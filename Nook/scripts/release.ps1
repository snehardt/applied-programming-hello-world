. "$PSScriptRoot\environment.ps1"
# Builds a local artifact only; never starts a server or deploys anything.
& "$PSScriptRoot\assets.ps1"
$nookPreviousMixEnv = $env:MIX_ENV
try {
  $env:MIX_ENV = 'prod'
  Invoke-NookMix deps.get --only prod
  Invoke-NookMix compile --warnings-as-errors
  Invoke-NookMix phx.digest
  Invoke-NookMix release --overwrite
} finally { $env:MIX_ENV = $nookPreviousMixEnv }
Write-Host 'Local release prepared in _build/prod/rel/nook. Nothing was published or started.'
