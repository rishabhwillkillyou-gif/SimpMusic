# RishiFy One-Step Setup for Windows (PowerShell 5.1+)
# This downloads two auditable scripts from the pinned project commit.
# The PRIVATE signing key is generated and kept on YOUR PC, never sent through this chat.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo = 'rishabhwillkillyou-gif/SimpMusic'
$ref = 'a536d08c039f02e7ab470f857cf80f5726e8bb26'
$base = "https://raw.githubusercontent.com/$repo/$ref/scripts/rishify"
$temp = Join-Path $env:TEMP ('rishify-setup-' + [guid]::NewGuid().ToString('N'))
$recoveryScript = Join-Path $temp 'Find-RishiFy-V04SigningKey.ps1'
$newKeyScript = Join-Path $temp 'New-RishiFySigningKey.ps1'
$signFolder = if (Test-Path 'F:\') { 'F:\RishiFy\Signing' } else { Join-Path $env:USERPROFILE 'Documents\RishiFy\Signing' }
$secretFile = Join-Path $signFolder 'RishiFy-PRIVATE-GitHub-Secrets.txt'
$workflowUrl = "https://github.com/$repo/actions/workflows/rishify-permanent-signed-release.yml"
try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    Write-Host ''
    Write-Host '=== RISHIFY SIGNING SETUP ===' -ForegroundColor Cyan
    Write-Host 'Step 1/3: Check for the original v0.4 key' -ForegroundColor Cyan
    Invoke-WebRequest -UseBasicParsing -Uri "$base/Find-RishiFy-V04SigningKey.ps1" -OutFile $recoveryScript
    Invoke-WebRequest -UseBasicParsing -Uri "$base/New-RishiFySigningKey.ps1" -OutFile $newKeyScript
    if (-not (Test-Path $recoveryScript) -or -not (Test-Path $newKeyScript)) {
        throw 'Signing setup files could not be downloaded. No keys were changed.'
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recoveryScript
    $result = $LASTEXITCODE
    if ($result -eq 42) {
        Write-Host ''
        Write-Host 'The original signing key was found! Stop here; we can prepare an in-place v0.5 update instead.' -ForegroundColor Green
        Write-Host 'Keep the identified file safe. Share ONLY its path, not the keystore or passwords.'
        return
    }
    if ($result -ne 0) { throw "Recovery search failed with exit code $result. No new key will be generated." }

    Write-Host ''
    Write-Host 'No original key was automatically verified.' -ForegroundColor Yellow
    Write-Host 'Any additional keystore candidates listed above could require their original passwords.'
    $choice = Read-Host 'Create ONE permanent key for RishiFy v0.5 and all later updates? (Y/n)'
    if ($choice -notmatch '^(|y|yes)$') {
        Write-Host 'No new key generated. Your existing RishiFy installation has not been changed.'
        return
    }

    Write-Host ''
    Write-Host 'Step 2/3: Create the permanent key on this PC' -ForegroundColor Cyan
    if ((Test-Path (Join-Path $signFolder 'rishify-permanent-release.p12')) -and
        (Test-Path $secretFile)) {
        Write-Host "An existing permanent key and recovery file were found in $signFolder."
        Write-Host 'They will be reused. The key will NEVER be overwritten.' -ForegroundColor Green
    } else {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $newKeyScript
        if ($LASTEXITCODE -ne 0) {
            throw 'Key generation did not complete. Resolve the displayed error without deleting any existing signing files.'
        }
    }
    if (-not (Test-Path $secretFile)) { throw 'Private recovery file not found. Do not proceed with signing.' }

    Write-Host ''
    Write-Host 'Step 3/3: Safely register the signing key in GitHub Actions' -ForegroundColor Cyan
    $ghCommand = Get-Command gh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    $ghExe = if ($ghCommand) { $ghCommand.Source } else { $null }
    if (-not $ghExe) {
        $possibleGh = Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'
        if (Test-Path $possibleGh) { $ghExe = $possibleGh }
    }
    if (-not $ghExe) {
        $install = Read-Host 'Install the official GitHub CLI to upload the signing secrets automatically? (Y/n)'
        if ($install -match '^(|y|yes)$') {
            $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
            if ($winget) {
                & winget install --id GitHub.cli --exact --source winget --accept-package-agreements --accept-source-agreements
                $possibleGh = Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'
                if (Test-Path $possibleGh) { $ghExe = $possibleGh }
            } else {
                Write-Warning 'Windows Package Manager was not found. GitHub CLI was not installed.'
            }
        }
    }
    if (-not $ghExe) {
        Write-Host ''
        Write-Host 'Your permanent key has been generated and saved on your PC.' -ForegroundColor Green
        Write-Host "Private recovery file: $secretFile"
        Write-Host "Open https://github.com/$repo/settings/secrets/actions"
        Write-Host 'Create the five Repository secrets listed in that PRIVATE file.'
        Write-Host 'Then use the RishiFy Permanent Signed APK workflow.'
        return
    }

    # gh prints unauthenticated status on stderr; do not let strict PowerShell
    # error handling abort before the normal browser login prompt.
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $ghExe auth status --hostname github.com *> $null
        $authExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorPreference
    }
    if ($authExitCode -ne 0) {
        Write-Host 'GitHub will open a browser to authorize your account. No key material is shared until authorization succeeds.'
        & $ghExe auth login --hostname github.com --git-protocol https --web
        if ($LASTEXITCODE -ne 0) { throw 'GitHub login was not completed. The local signing key remains safe.' }
    }
    Write-Host 'Registering all five GitHub Actions secrets without displaying their values...'
    & $ghExe secret set --repo $repo --env-file $secretFile
    if ($LASTEXITCODE -ne 0) { throw 'Could not register the signing secrets. The local backup is intact.' }
    Write-Host 'Permanent signing secrets configured successfully!' -ForegroundColor Green

    $build = Read-Host 'Start the RishiFy v0.5 signing workflow now? (Y/n)'
    if ($build -match '^(|y|yes)$') {
        & $ghExe workflow run rishify-permanent-signed-release.yml --repo $repo --ref personal-music-v0.5-mobile
        if ($LASTEXITCODE -ne 0) { throw 'Could not start the workflow; open the Actions link to start it manually.' }
        Start-Process $workflowUrl
        Write-Host 'The release workflow was requested. Its Actions page is open in your browser.'
        Write-Host 'Download the APK only from a successful, verified workflow run.'
    } else {
        Write-Host "You can run the build later at $workflowUrl"
    }
    Write-Host ''
    Write-Warning "Back up the .p12 keystore AND private recovery file securely, outside this PC. Never share either file in chat."
    Write-Host 'Do not uninstall v0.4; it has a different application ID, and v0.5 can be installed beside it.'
} catch {
    Write-Host ''
    Write-Host ('Setup stopped: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Your v0.4 installation has NOT been uninstalled or modified.'
    Write-Host "If already generated, preserve signing files in: $signFolder"
} finally {
    Remove-Item -LiteralPath $temp -Force -Recurse -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host 'Setup finished. Press Enter to close if this window was launched separately.'
}
