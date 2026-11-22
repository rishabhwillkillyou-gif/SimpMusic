# RishiFy permanent Android signing key (Windows PowerShell 5.1+)
# Run locally only. Never commit the generated key or the private recovery file.
[CmdletBinding()]
param([string]$Destination = "")
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Destination)) {
    if (Test-Path "F:\") { $Destination = "F:\RishiFy\Signing" }
    else { $Destination = Join-Path $env:USERPROFILE "Documents\RishiFy\Signing" }
}
if (-not (Test-Path $Destination)) { New-Item -ItemType Directory -Path $Destination -Force | Out-Null }
$Destination = (Resolve-Path $Destination).Path
$Keystore = Join-Path $Destination "rishify-permanent-release.p12"
$Recovery = Join-Path $Destination "RishiFy-PRIVATE-GitHub-Secrets.txt"
if ((Test-Path $Keystore) -or (Test-Path $Recovery)) {
    throw "Existing signing files found in $Destination. Stopping to avoid accidental key replacement."
}
$keytoolCommand = Get-Command keytool.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$keytool = if ($keytoolCommand) { $keytoolCommand.Source } else { $null }
if (-not $keytool) {
    $paths = @(
        "$env:ProgramFiles\Microsoft\jdk-21*\bin\keytool.exe",
        "$env:ProgramFiles\Eclipse Adoptium\jdk-21*\bin\keytool.exe",
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe"
    )
    foreach ($p in $paths) {
        $match = @(Get-Item -Path $p -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($match.Count -gt 0) { $keytool = $match[0].FullName; break }
    }
}
if (-not $keytool) {
    throw "Java keytool not found. Install JDK 21 first (for example: winget install Microsoft.OpenJDK.21), open a new PowerShell window, and rerun."
}
$randomBytes = New-Object 'byte[]' 36
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($randomBytes) } finally { $rng.Dispose() }
$password = [Convert]::ToBase64String($randomBytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
$env:RISHIFY_TEMP_KEY_PASS = $password
try {
    & $keytool -genkeypair -v -keystore $Keystore -storetype PKCS12 -alias rishify -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=RishiFy Permanent Signing, OU=Personal Android, O=RishiFy, C=IN" -storepass:env RISHIFY_TEMP_KEY_PASS -keypass:env RISHIFY_TEMP_KEY_PASS -noprompt
    if ($LASTEXITCODE -ne 0) { throw "keytool failed to generate the permanent key." }
    $details = (& $keytool -list -v -keystore $Keystore -storetype PKCS12 -alias rishify -storepass:env RISHIFY_TEMP_KEY_PASS | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "Unable to verify newly generated keystore." }
    $fingerprint = [regex]::Match($details, 'SHA256:\s*([0-9a-fA-F:]+)')
    if (-not $fingerprint.Success) { throw "Keystore created but its certificate fingerprint could not be read." }
    $sha256 = $fingerprint.Groups[1].Value.Replace(":", "").ToLowerInvariant()
    $b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Keystore))
    $lines = @(
        "# PRIVATE RISHIFY SIGNING RECOVERY. NEVER UPLOAD TO A PUBLIC REPOSITORY.",
        "# Add these FIVE NAME/VALUE pairs individually in GitHub:",
        "# Repository > Settings > Secrets and variables > Actions > New repository secret",
        "",
        "RISHIFY_KEYSTORE_B64=$b64",
        "RISHIFY_KEYSTORE_PASSWORD=$password",
        "RISHIFY_KEY_ALIAS=rishify",
        "RISHIFY_KEY_PASSWORD=$password",
        "RISHIFY_CERT_SHA256=$sha256",
        "",
        "# Store this file and the .p12 keystore in a secure, offline backup.",
        "# Future builds MUST keep the same key, application ID and increasing version code."
    )
    [System.IO.File]::WriteAllLines($Recovery, $lines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host "SUCCESS: Permanent RishiFy signing key created." -ForegroundColor Green
    Write-Host "Keystore : $Keystore"
    Write-Host "Secrets  : $Recovery"
    Write-Host "SHA-256  : $sha256"
    Write-Host ""
    Write-Warning "The PRIVATE secrets text includes the full key and password. Back it up securely. Never post it in chat, commit it to GitHub, or share it."
    Write-Host "Set all FIVE GitHub Actions secrets, then run the 'RishiFy Permanent Signed APK' workflow on the v0.5 branch."
} finally {
    Remove-Item Env:RISHIFY_TEMP_KEY_PASS -ErrorAction SilentlyContinue
}
