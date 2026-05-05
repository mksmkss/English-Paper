# English Paper Reader Release Checklist

This project ships outside the Mac App Store.

## What is automated

- `./App/build-app.sh`
  - Generates the app icon.
  - Builds the app bundle.
  - Falls back to direct `swiftc` compilation if `swift build` is blocked by the local SwiftPM manifest bug.
- `./App/package-release.sh`
  - Builds the app bundle.
  - Creates a release zip.
  - Creates a DMG.
  - Signs the app and DMG when `DEVELOPER_ID_APP_CERT` is set.
  - Notarizes and staples the DMG when `NOTARY_PROFILE` is set.

## Environment for signed distribution

- Install a valid Developer ID Application certificate in Keychain.
- Confirm `security find-identity -v -p codesigning` shows that identity.
- Store notarization credentials once:

```bash
xcrun notarytool store-credentials papers-notary
```

## Signed release command

```bash
DEVELOPER_ID_APP_CERT="Developer ID Application: YOUR NAME (TEAMID)" \
NOTARY_PROFILE="papers-notary" \
./App/package-release.sh
```

## Output

- App bundle: `.build-release/PapersApp.app`
- Zip archive: `dist/PapersApp-macOS.zip`
- Disk image: `dist/PapersApp.dmg`

## Manual final checks

- Open the built app on a clean macOS user account.
- Verify PDF import, selection, quick register, hover meaning, appearance jump, and zoom.
- Verify tooltip text appears for icon-only controls.
- If signed and notarized, run `spctl -a -vv dist/PapersApp.dmg` and confirm Gatekeeper accepts it.

## Apple guidance used

- HIG `App icons`
- HIG `Toolbars`
- HIG `Windows`
- HIG `Sidebars`
- HIG `Offering help`
- HIG `Alerts`
- Apple Developer `Developer ID`
- Apple Developer `Packaging Mac software for distribution`
