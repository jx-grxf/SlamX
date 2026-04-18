# Sparkle Updates

SlamDih uses Sparkle 2 for in-app updates.

## Important

- The Sparkle private signing key is stored in the local macOS login Keychain.
- The embedded public key is stored in `Resources/Info.plist` as `SUPublicEDKey`.
- Sparkle needs a public `appcast.xml` and public DMG asset URL. Private GitHub release assets do not work for normal users because Sparkle does not have GitHub authentication.

## Release Flow

Build the DMG:

```bash
./scripts/create-dmg.sh 0.2.0
```

Generate the appcast:

```bash
./scripts/generate-appcast.sh .build/dmg
```

Optional but recommended: add release notes next to the DMG before generating the appcast.
The filename must match the DMG basename:

```text
.build/dmg/SlamDih-0.2.0.md
```

These notes are embedded into `appcast.xml`, so Sparkle can show the changelog in its update window without another release asset.

Upload these release assets:

- `.build/dmg/SlamDih-0.2.0.dmg`
- `.build/dmg/SlamDih-0.2.0.dmg.sha256`
- `.build/dmg/appcast.xml`

The app checks this feed:

```text
https://github.com/jx-grxf/SlamDih/releases/latest/download/appcast.xml
```

## Testing

Sparkle only sees an update if the published `sparkle:version` is higher than the installed app's `CFBundleVersion`.

To force an immediate check during local testing:

```bash
defaults delete com.johannesgrof.slamdih SULastCheckTime
```

Then launch the app and use `SlamDih > Check for Updates...`.
