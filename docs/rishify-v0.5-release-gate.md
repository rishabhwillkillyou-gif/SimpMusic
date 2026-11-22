# RishiFy Android v0.5 — release gate

Base: mobile v0.4 commit d0f294781c82481ba590a558c4643cafe286064c. Core is pinned to the v0.5 mobile implementation. Do not merge into main or the v0.4 branch until validated.

## Test before distribution
- Build the same personalized debug variant as run #34 (38537383000). Its workflow file was not returned by the checked-out tree; recover the original personal build workflow and original branding/signing configuration from the local checkout or history. Do not substitute a release build or a fresh key.
- Compare actual v0.4 and candidate APKs with `apksigner verify --print-certs` and `apkanalyzer manifest application-id` / `apkanalyzer manifest version-code`. Package ID and SHA-256 signing certificate must match, and candidate version code must be strictly higher. Never uninstall the old app to make an update work.
- Verify update using `adb install -r candidate.apk` on a test device first; preserve saved playlists, favourites, history, EQ, preferences and offline tracks.
- Test Play Next for a future track, previous track, already-next track, repeated taps and changed queue while the menu is open; current position must not reset and the other tracks must retain order.
- Test Refresh Radio during playback and pause: old queue stays until recommendations arrive, current item stays uninterrupted, manually queued tracks stay in order, no duplicate recommendations. Test offline, network timeout, empty response, switching tracks mid-request, repeated refresh and disabling endless queue. Confirm subsequent continuation uses new radio. Test queue exhaustion and v0.4 regressions.
- Refresh is initially disabled while shuffle is enabled, since the existing Android adapter can recreate shuffle order on append; test correct behavior before adding shuffle support. Manual queue provenance is tracked in the active queue session; persistence across a process restart is not implemented yet.
- Review and compile shared UI and Android core, then run device tests before publishing. No new signing credentials should be generated.
