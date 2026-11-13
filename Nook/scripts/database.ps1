param([switch]$Install, [switch]$Stop)
. "$PSScriptRoot\environment.ps1"
if ($env:DATABASE_URL) { return }
$nookPgRoot = Join-Path $nookDatabaseHome 'postgresql-17.6'
$nookPgBin = Join-Path $nookPgRoot 'pgsql\bin'
$nookPgData = Join-Path $nookDatabaseHome 'pgdata'
if (!(Test-Path "$nookPgBin\pg_ctl.exe") -or !(Test-Path "$nookPgRoot\pgsql\share\timezonesets")) {
  if (!$Install) { throw 'PostgreSQL is not set up. Run .\scripts\setup.ps1 first.' }
  New-Item -ItemType Directory -Force $nookDatabaseHome | Out-Null
  $nookDownload = Join-Path $env:TEMP 'nook-postgres.zip'
  Invoke-WebRequest 'https://get.enterprisedb.com/postgresql/postgresql-17.6-1-windows-x64-binaries.zip' -OutFile $nookDownload
  Expand-Archive -LiteralPath $nookDownload -DestinationPath $nookPgRoot -Force
}
if ($Stop) {
  & "$nookPgBin\pg_ctl.exe" -D $nookPgData -m fast -w stop
  if ($LASTEXITCODE -ne 0) { throw 'Could not stop the Nook database.' }
  return
}
if (!(Test-Path "$nookPgData\PG_VERSION")) {
  if (!$Install) { throw 'Database cluster is missing. Run .\scripts\setup.ps1.' }
  if (!(Test-Path $nookCredentialsPath)) {
    $nookRandom = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($nookRandom)
    @{password=[Convert]::ToBase64String($nookRandom)} | ConvertTo-Json | Set-Content -LiteralPath $nookCredentialsPath
  }
  $nookPassword = (Get-Content -LiteralPath $nookCredentialsPath -Raw | ConvertFrom-Json).password
  $nookPasswordFile = Join-Path $nookDatabaseHome 'init-password.tmp'
  try {
    Set-Content -LiteralPath $nookPasswordFile -Value $nookPassword
    & "$nookPgBin\initdb.exe" -D $nookPgData -U nook -A scram-sha-256 --pwfile=$nookPasswordFile --encoding=UTF8 --locale=C
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the Nook database.' }
    Add-Content -LiteralPath "$nookPgData\postgresql.conf" -Value "`nlisten_addresses = '127.0.0.1'`nport = 55432"
  } finally { Remove-Item -LiteralPath $nookPasswordFile -ErrorAction SilentlyContinue }
}
. "$PSScriptRoot\environment.ps1"
& "$nookPgBin\pg_ctl.exe" -D $nookPgData status *> $null
if ($LASTEXITCODE -ne 0) {
  & "$nookPgBin\pg_ctl.exe" -D $nookPgData -l "$nookDatabaseHome\postgres.log" -w start
  if ($LASTEXITCODE -ne 0) { throw 'Could not start PostgreSQL. See %LOCALAPPDATA%\Nook\postgres.log.' }
}
