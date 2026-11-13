$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$nookOtpBin = Join-Path $env:USERPROFILE '.elixir-install\installs\otp\27.3.4.2\bin'
$nookElixirBin = Join-Path $env:USERPROFILE '.elixir-install\installs\elixir\1.18.4-otp-27\bin'
if ((Test-Path $nookOtpBin) -and ($env:PATH.Split(';') -notcontains $nookOtpBin)) { $env:PATH = "$nookOtpBin;$nookElixirBin;$env:PATH" }
$nookDatabaseHome = Join-Path $env:LOCALAPPDATA 'Nook'
$nookCredentialsPath = Join-Path $nookDatabaseHome 'database.json'
if (!$env:DATABASE_URL -and (Test-Path $nookCredentialsPath)) {
  $nookDatabaseConfig = Get-Content -LiteralPath $nookCredentialsPath -Raw | ConvertFrom-Json
  $env:NOOK_DATABASE_PASSWORD = $nookDatabaseConfig.password
  $env:PGPORT = '55432'
  $env:PGUSER = 'nook'
}
function Invoke-NookMix {
  & mix @args
  if ($LASTEXITCODE -ne 0) { throw "mix command failed (exit $LASTEXITCODE)." }
}
