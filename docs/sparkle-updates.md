# Sparkle Updates

SlamX uses Sparkle 2 for in-app updates.

## Important

- The Sparkle private signing key is stored in the local macOS login Keychain.
- The embedded public key is stored in `Resources/Info.plist` as `SUPublicEDKey`.
- Sparkle needs a public `appcast.xml` and public DMG asset URL. Private GitHub release assets do not work for normal users because Sparkle does not have GitHub authentication.
- Sparkle signing is not the same as Apple Developer ID signing. Local/ad-hoc builds can be updated by Sparkle, but they are not notarized and are not a polished public binary distribution.
- Developer ID signing and notarization require Apple Developer Program membership. Until that is available, treat generated DMGs as technical preview builds.

## Release Flow

Build a local `.app` bundle through the Xcode project:

```bash
./scripts/package-app.sh 0.2.0 2
```

This is the source of truth for packaging. Do not build the release app by manually copying the SwiftPM executable into an `.app` bundle; Sparkle and embedded frameworks need Xcode's app bundle layout.

By default this creates an ad-hoc signed local build. If a Developer ID identity is available later, pass it explicitly:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package-app.sh 0.2.0 2
```

Build the DMG:

```bash
./scripts/create-dmg.sh 0.2.0 2
```

Generate the appcast:

```bash
./scripts/generate-appcast.sh .build/dmg
```

For a GitHub release, prefer the combined asset script:

```bash
./scripts/create-release-assets.sh 0.2.0 2
```

This creates the DMG, checksum, appcast, and source archives with `SlamX` asset names. The script fails if a legacy `SlamDih*` release asset name is produced.
The appcast DMG enclosure uses the concrete GitHub release tag URL by default, so clients do not depend on the mutable `latest` redirect while downloading the update. If you override `APPCAST_DOWNLOAD_URL_PREFIX`, provide the directory URL for the release assets; the script normalizes a missing trailing slash.

The script writes a release-notes file next to the DMG before generating the appcast.
The filename matches the DMG basename:

```text
.build/dmg/SlamX-0.2.0.html
```

These notes are embedded into `appcast.xml`, so Sparkle can show the changelog in its update window without another release asset. Pass `RELEASE_NOTES_FILE=/path/to/notes.html` to use curated notes instead of the generated commit list.
For release tags that differ from the numeric app version, such as `v0.3.4-fix`, keep the app version Apple-compatible and set the tag explicitly:

```bash
RELEASE_TAG=v0.3.4-fix ./scripts/create-release-assets.sh 0.3.4 8
```

Upload these release assets:

- `.build/dmg/SlamX-0.2.0.dmg`
- `.build/dmg/SlamX-0.2.0.dmg.sha256`
- `.build/dmg/appcast.xml`
- `.build/dmg/SlamX-0.2.0-source.zip`
- `.build/dmg/SlamX-0.2.0-source.tar.gz`

The app checks this feed:

```text
https://github.com/jx-grxf/SlamX/releases/latest/download/appcast.xml
```

For a paid/private-source future, the source repository can remain private, but the appcast and binary asset still need to be public or otherwise reachable without GitHub authentication.

## Public Build Checklist

- Confirm no secrets or private keys are committed.
- Confirm the app has no microphone permission or fallback UI.
- Confirm the README explains sensor-only support and update network access.
- Run tests before generating the DMG.
- Validate `appcast.xml` before upload.
- Before presenting a build to non-technical users, sign with Developer ID, notarize, staple the ticket, and test launch on a Gatekeeper-enabled Mac.

## Testing

Sparkle only sees an update if the published `sparkle:version` is higher than the installed app's `CFBundleVersion`.
For example, if the installed local app is `0.2.0` build `2`, publish the test update as `0.2.1` build `3`:

```bash
./scripts/create-dmg.sh 0.2.1 3
./scripts/generate-appcast.sh .build/dmg
```

To force an immediate check during local testing:

```bash
defaults delete com.johannesgrof.slamx SULastCheckTime
```

Then launch the app and use `SlamX > Check for Updates...`.
