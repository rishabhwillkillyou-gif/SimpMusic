# Search for the v0.4 signing key on your own Windows PC.
# GitHub Actions generated the October debug key on a temporary runner, so a local match is unlikely.
[CmdletBinding()]
param([switch]$DeepScanF)
$ErrorActionPreference = "Stop"
$Expected = "fcf4948c89a9ebd610840704624ae00c17dcb04732685a8c77b693213e9faac2"
$roots = @(
    (Join-Path $env:USERPROFILE ".android"),
    (Join-Path $env:USERPROFILE "Downloads"),
    (Join-Path $env:USERPROFILE "Documents"),
    "F:\RishiFy", "F:\Android", "F:\Projects"
)
if ($DeepScanF -and (Test-Path "F:\")) { $roots += "F:\" }
$keytoolCommand = Get-Command keytool.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$keytool = if ($keytoolCommand) { $keytoolCommand.Source } else { $null }
if (-not $keytool) {
    $candidate = "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe"
    if (Test-Path $candidate) { $keytool = $candidate }
}
$found = @{}
foreach ($root in ($roots | Select-Object -Unique)) {
    if (-not (Test-Path $root)) { continue }
    Write-Host "Searching $root"
    Get-ChildItem -Path $root -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '(?i)(\.jks$|\.keystore$|\.p12$|\.pfx$)' } |
        ForEach-Object { $found[$_.FullName] = $true }
}
Write-Host ""
if ($found.Count -eq 0) {
    Write-Warning "No key files found in the searched locations. Original October key may only have existed on GitHub's temporary runner."
    exit 0
}
$verifiedMatches = @()
foreach ($file in ($found.Keys | Sort-Object)) {
    Write-Host "Candidate: $file"
    if ($file -match '(?i)debug\.keystore$' -and $keytool) {
        $env:RISHIFY_SCAN_DEBUG_PASS = "android"
        try {
            $details = (& $keytool -list -v -keystore $file -storepass:env RISHIFY_SCAN_DEBUG_PASS 2>$null | Out-String)
            $fingerprint = [regex]::Match($details, 'SHA256:\s*([0-9a-fA-F:]+)')
            if ($fingerprint.Success) {
                $sha = $fingerprint.Groups[1].Value.Replace(":", "").ToLowerInvariant()
                if ($sha -eq $Expected) { $verifiedMatches += $file }
            }
        } catch { } finally { Remove-Item Env:RISHIFY_SCAN_DEBUG_PASS -ErrorAction SilentlyContinue }
    }
}
if ($verifiedMatches.Count -gt 0) {
    Write-Host "MATCH! The old v0.4 certificate was found:" -ForegroundColor Green
    $verifiedMatches | ForEach-Object { Write-Host $_ }
    Write-Warning "Keep the matching private key safe. Do not create a replacement key until this is reviewed."
} else {
    Write-Warning "No automatically verified match found. Other candidates may require their original passwords."
    Write-Host "Expected v0.4 certificate SHA-256: $Expected"
}
