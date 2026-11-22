# RishiFy v0.5 permanent Android signing

## Why fresh installation is required

The previous October APK was **com.maxrave.simpmusic.dev**, version code **58**, and its public signer certificate SHA-256 was:

fcf4948c89a9ebd610840704624ae00c17dcb04732685a8c77b693213e9faac2

The October APK was generated on a temporary GitHub Actions runner with an auto-generated debug keystore. No keystore file exists in the checked GitHub history/artifacts or Drive search, and there is no usable existing GitHub Actions signing secret configuration. The private signing key cannot be derived from the APK or its public certificate. It might still exist in an external or local backup not accessible from GitHub.

The permanent-release APK uses **com.maxrave.simpmusic** (without .dev), allowing it to be installed beside the previous debug application without removing the old data.

This is a **one-time fresh-install migration**, not an update of v0.4. Existing v0.4 playlists and app settings are NOT automatically transferred.

## Step 1: optional local check for the original key

On Windows, download and inspect:
scripts/rishify/Find-RishiFy-V04SigningKey.ps1

Run from PowerShell:
powershell -ExecutionPolicy Bypass -File .\Find-RishiFy-V04SigningKey.ps1

For a deeper search on F:, add -DeepScanF. A verified match means you can preserve the old app's signing identity; do not proceed with a new key until reviewing the match.

## Step 2: create permanent signing material on your own Windows PC

Ensure Java JDK 21 and keytool are installed (e.g., winget install Microsoft.OpenJDK.21). Run:
powershell -ExecutionPolicy Bypass -File .\New-RishiFySigningKey.ps1

Default output folder:
F:\RishiFy\Signing

Two important PRIVATE files are created there:
- rishify-permanent-release.p12 — permanent private signing key (RSA 3072 / PKCS12)
- RishiFy-PRIVATE-GitHub-Secrets.txt — generated strong password, encoded keystore and SHA-256 fingerprint for GitHub secrets

The script refuses to overwrite an existing keystore. Run it ONLY ONCE. Do not commit these files, post them in messages or put them into a public storage location. Keep a secure offline backup of both, preferably separately in encrypted storage.

## Step 3: configure GitHub Actions once

Open:
https://github.com/rishabhwillkillyou-gif/SimpMusic/settings/secrets/actions

Create these 5 Repository secrets using the private file's corresponding values:

1. RISHIFY_KEYSTORE_B64
2. RISHIFY_KEYSTORE_PASSWORD
3. RISHIFY_KEY_ALIAS
4. RISHIFY_KEY_PASSWORD
5. RISHIFY_CERT_SHA256

Or use the GitHub CLI after authenticating it on your own PC:

gh auth login
gh secret set --repo rishabhwillkillyou-gif/SimpMusic --env-file "F:\RishiFy\Signing\RishiFy-PRIVATE-GitHub-Secrets.txt"

Never paste the values into a GitHub issue, pull request, repository file, public log, or chat.

## Step 4: get signed v0.5

From Actions, open "RishiFy Permanent Signed APK" and choose "Run workflow" using ref personal-music-v0.5-mobile.

The workflow:
- Verifies that all 5 secrets exist
- Builds a full personal release using pinned Android v0.5 source and original RishiFy branding
- Signs using the recovered key file from the GitHub secret, not a temporary debug key
- Validates signer fingerprint matches RISHIFY_CERT_SHA256
- Checks app ID com.maxrave.simpmusic and version code 59
- Uploads RishiFy-v0.5-PERMANENT-SIGNED-ARM64 artifact only after all checks pass

Download the APK from the successful workflow artifact.

## Step 5: install safely

Keep the old v0.4 debug application installed initially. The new v0.5 release app is a separate Android package and will start with separate app data. If the old app has a working export/backup option, use it before moving data; data migration is not guaranteed. Install v0.5, test Play Next, Refresh Radio, playlists, downloads and streaming. Remove the old app only after you are satisfied.

## Future updates

Every subsequent release must:
- Use the SAME com.maxrave.simpmusic package
- Reuse the SAME private keystore, alias and password
- Match the pinned RISHIFY_CERT_SHA256 certificate fingerprint
- Increase versionCode to at least 60 for v0.6

NEVER regenerate a signing key for an update. If a release reports signing mismatch, STOP rather than uninstalling. The key is retained outside the public repository, backed up on the owner's PC, and configured in GitHub Actions secrets.

## Security and verification caveats

The signing workflow provides repeatable cryptographic identity; it does not by itself prove all new queue/radio functionality works on a physical device. Device testing is still necessary before deleting v0.4.

If a saved copy of the original v0.4 debug keystore is found, a different upgrade-compatible .dev build may become possible. Confirm its full SHA-256 fingerprint before choosing that path.
