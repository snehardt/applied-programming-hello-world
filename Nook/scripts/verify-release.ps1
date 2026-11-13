param([switch]$GoogleOnly)
. "$PSScriptRoot\environment.ps1"
# Boot the local production artifact with HTTP disabled; no email is sent.
$nookVerifyKeys=@('SECRET_KEY_BASE','NOOK_HOST','DATABASE_URL','DATABASE_SSL','SMTP_HOST','SMTP_USERNAME','SMTP_PASSWORD','MAIL_FROM','PHX_SERVER','NOOK_AUTH_MODE','GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET','GOOGLE_REDIRECT_URI')
$nookSavedVerifyEnv=@{}
foreach($nookVerifyKey in $nookVerifyKeys){$nookSavedVerifyEnv[$nookVerifyKey]=[Environment]::GetEnvironmentVariable($nookVerifyKey)}
try {
 $env:SECRET_KEY_BASE=[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(64))
 $env:NOOK_HOST='nook.example.test'
 if(!$env:DATABASE_URL){$env:DATABASE_URL='ecto://nook:'+[Uri]::EscapeDataString($env:NOOK_DATABASE_PASSWORD)+'@127.0.0.1:55432/nook_dev';$env:DATABASE_SSL='false'}
 $env:SMTP_HOST='smtp.example.test';$env:SMTP_USERNAME='unused';$env:SMTP_PASSWORD='unused';$env:MAIL_FROM='nook@example.test';$env:PHX_SERVER='false'
 if($GoogleOnly){
   $env:NOOK_AUTH_MODE='google';$env:GOOGLE_CLIENT_ID='release-test-only';$env:GOOGLE_CLIENT_SECRET='release-test-only';$env:GOOGLE_REDIRECT_URI='https://nook.example.test/auth/google/callback'
   $env:SMTP_HOST=$null;$env:SMTP_USERNAME=$null;$env:SMTP_PASSWORD=$null;$env:MAIL_FROM=$null
 }else{$env:NOOK_AUTH_MODE='email';$env:GOOGLE_CLIENT_ID=$null;$env:GOOGLE_CLIENT_SECRET=$null;$env:GOOGLE_REDIRECT_URI=$null}
 & .\_build\prod\rel\nook\bin\nook.bat eval 'Code.eval_file(~s(scripts/verify_release.exs))'
 if($LASTEXITCODE -ne 0){throw 'Local release verification failed.'}
} finally {foreach($nookVerifyKey in $nookVerifyKeys){[Environment]::SetEnvironmentVariable($nookVerifyKey,$nookSavedVerifyEnv[$nookVerifyKey])}}
