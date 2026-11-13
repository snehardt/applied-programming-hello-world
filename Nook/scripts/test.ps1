. "$PSScriptRoot\environment.ps1"
& "$PSScriptRoot\database.ps1"
$nookPreviousMixEnv = $env:MIX_ENV
try {
  $env:MIX_ENV = 'test'
  Invoke-NookMix ecto.create
  Invoke-NookMix ecto.migrate
  Invoke-NookMix test
} finally { $env:MIX_ENV = $nookPreviousMixEnv }
node --test test/canvas-model.test.mjs test/collaboration-model.test.mjs test/ui-state.test.mjs test/history.test.mjs test/file-policy.test.mjs test/visual-tools.test.mjs test/drawing.test.mjs test/drawing-assist.test.mjs
if ($LASTEXITCODE -ne 0) { throw 'Canvas tests failed.' }
