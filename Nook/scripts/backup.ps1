param([switch]$VerifyRestore)
. "$PSScriptRoot\environment.ps1"
$nookPgBin = Join-Path $nookDatabaseHome 'postgresql-17.6\pgsql\bin'
if (!(Test-Path "$nookPgBin\pg_dump.exe")) { throw 'Set up the local PostgreSQL tools first.' }
if ($VerifyRestore -and $env:DATABASE_URL) { throw 'Restore verification is limited to the local Nook database.' }
$nookBackupPath = Join-Path (Get-Location) ('.nook-history/backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.dump')
New-Item -ItemType Directory -Force .nook-history | Out-Null
$nookSavedPassword = $env:PGPASSWORD
$nookSavedDatabase = $env:PGDATABASE
$nookTemporaryDatabase = 'nook_restore_check_' + [Guid]::NewGuid().ToString('N')
$nookCreatedTemporary = $false
try {
  if($env:DATABASE_URL) { $env:PGDATABASE = $env:DATABASE_URL } else { $env:PGDATABASE = 'nook_dev'; $env:PGPASSWORD = $env:NOOK_DATABASE_PASSWORD; $env:PGHOST = '127.0.0.1' }
  & "$nookPgBin\pg_dump.exe" -Fc -f $nookBackupPath
  if($LASTEXITCODE -ne 0){throw 'Backup failed.'}
  & "$nookPgBin\pg_restore.exe" --list $nookBackupPath | Out-Null
  if($LASTEXITCODE -ne 0){throw 'Backup could not be read.'}
  if($VerifyRestore){
    & "$nookPgBin\createdb.exe" $nookTemporaryDatabase
    if($LASTEXITCODE -ne 0){throw 'Could not create isolated restore-check database.'}
    $nookCreatedTemporary = $true
    & "$nookPgBin\pg_restore.exe" --exit-on-error --no-owner -d $nookTemporaryDatabase $nookBackupPath
    if($LASTEXITCODE -ne 0){throw 'Restore check failed.'}
    foreach($nookTable in @('boards','elements','users')) {
      $nookQuery = "SELECT count(*) FROM $nookTable"
      $nookOriginalCount = & "$nookPgBin\psql.exe" -At -c $nookQuery
      if($LASTEXITCODE -ne 0){throw 'Could not count source records.'}
      $nookRestoredCount = & "$nookPgBin\psql.exe" -At -d $nookTemporaryDatabase -c $nookQuery
      if($LASTEXITCODE -ne 0 -or $nookOriginalCount -ne $nookRestoredCount){throw 'Restored record counts did not match. Stop editing while checking a backup.'}
    }
    Write-Host 'Restore verified in an isolated temporary database; source database unchanged.'
  }
  (Get-FileHash -LiteralPath $nookBackupPath -Algorithm SHA256).Hash | Set-Content -LiteralPath ($nookBackupPath + '.sha256')
  Write-Host "Backup saved: $nookBackupPath"
} finally {
  if($nookCreatedTemporary){ & "$nookPgBin\dropdb.exe" $nookTemporaryDatabase }
  $env:PGPASSWORD=$nookSavedPassword
  $env:PGDATABASE=$nookSavedDatabase
}
