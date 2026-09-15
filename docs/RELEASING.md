# Releasing EasyNotch

> **Status: not set up yet.** The published releases of EasyNotch ship with the
> placeholder feed URL described below, so automatic updates do not work. This
> is a known, deliberate gap — wiring up a real appcast is planned for a future
> version. Until then, releases are distributed from the GitHub Releases page
> and installed manually. The rest of this document is the procedure for when
> that work is done, and for anyone distributing their own fork.

EasyNotch ships updates through [Sparkle 2](https://sparkle-project.org). The
integration in the app is complete, but two things in the root `Info.plist`
are pending until you generate keys and pick a hosting URL:

- `SUPublicEDKey` — your Sparkle EdDSA **public** key. This entry is
  **intentionally absent** for now: Sparkle refuses to start (with an error
  dialog at every launch) if the key is present but not a decodable Ed25519
  key, while a missing key is allowed. Add the entry only once you have the
  real value.
- `SUFeedURL` — the URL of your hosted `appcast.xml` (currently a
  placeholder).

Until both are configured, "Check for Updates…" will show a feed error. That
is expected.

## One-time setup

1. **Generate the signing keys.** Sparkle's tools are bundled with the SPM
   package. After the first build, find them under Xcode's DerivedData
   (`.../SourcePackages/artifacts/sparkle/Sparkle/bin/`) or download the
   Sparkle distribution from https://github.com/sparkle-project/Sparkle/releases.

   ```sh
   ./bin/generate_keys
   ```

   This stores the **private** key in your login Keychain (item name
   "Private key for signing Sparkle updates") and prints the **public** key.

2. **Add the public key** to the root `Info.plist` as a new entry:

   ```xml
   <key>SUPublicEDKey</key>
   <string>the-public-key-printed-by-generate_keys</string>
   ```

3. **Choose the appcast URL** and put it in `Info.plist` as `SUFeedURL`.
   The simplest options:
   - GitHub Pages: `https://<user>.github.io/EasyNotch/appcast.xml`
   - A file committed to the repo and served raw:
     `https://raw.githubusercontent.com/<user>/EasyNotch/main/appcast.xml`

Back up the private key (Keychain export). Losing it means existing installs
can never verify another update.

## Every release

1. Bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in the Xcode
   project.
2. Archive in Xcode (Product → Archive), export a Developer ID–signed build,
   and notarize it (Xcode's Organizer does both).
3. Put the app in a DMG (or zip) named for the version, e.g.
   `EasyNotch-1.1.dmg`.
4. Generate/refresh the appcast from a folder containing all release
   archives:

   ```sh
   ./bin/generate_appcast /path/to/release-archives/
   ```

   This signs each archive with the private key from the Keychain and writes
   `appcast.xml` next to them.
5. Upload the archives and `appcast.xml` to wherever `SUFeedURL` points
   (e.g. attach the DMG to a GitHub release and commit/push the appcast).

## Notes

- The app is **not** sandboxed (`ENABLE_APP_SANDBOX = NO` in both build
  configurations). The Sparkle installer is nonetheless wired to run through
  its XPC launcher service: `SUEnableInstallerLauncherService` is already set
  in `Info.plist`, and the `-spks`/`-spki` mach-lookup entitlements are already
  in `EasyNotch/EasyNotch.entitlements`.
- Test an update end-to-end before publishing: host the appcast locally,
  point `SUFeedURL` at it in a debug build, and confirm the full
  download-install-relaunch cycle.
