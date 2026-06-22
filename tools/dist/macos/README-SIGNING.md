# Signing & notarizing Continuum.app

`make macos` always builds the bundle. By default it **ad-hoc** signs it, which
runs locally but is Gatekeeper-quarantined when *downloaded* ("Continuum.app is
damaged"). To produce a download that launches cleanly, the bundle must be
signed with a **Developer ID Application** certificate and **notarized** by
Apple. The pipeline is built into `build-macos.sh` and turns on when two env
vars are set:

```sh
CONTINUUM_SIGN_ID="Developer ID Application: Your Name (TEAMID)" \
CONTINUUM_NOTARY_PROFILE="continuum-notary" \
make macos
```

Requires a paid Apple Developer Program membership. One-time setup below.

## 1. Developer ID Application certificate (once per Mac)

Easiest via Xcode (creates the CSR + private key for you):

1. Xcode ▸ Settings ▸ Accounts ▸ add your Apple ID (the Developer account).
2. Select the team ▸ **Manage Certificates…** ▸ **+** ▸ **Developer ID Application**.
3. It installs into your login keychain. Confirm:

   ```sh
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

   The quoted string it prints (`Developer ID Application: Name (TEAMID)`) is
   your `CONTINUUM_SIGN_ID`. The `TEAMID` in parentheses is your Team ID.

## 2. App Store Connect API key (for notarytool)

1. https://appstoreconnect.apple.com ▸ Users and Access ▸ **Integrations** ▸
   **App Store Connect API** ▸ generate a key with the **Developer** role.
2. Download the `AuthKey_XXXXXXXXXX.p8` (you can only download it once). Note the
   **Key ID** (the `XXXXXXXXXX`) and the **Issuer ID** (UUID at the top).

## 3. Store a notarytool keychain profile (once)

Bundles the API key into the keychain so the build never handles secrets:

```sh
xcrun notarytool store-credentials "continuum-notary" \
    --key   /path/to/AuthKey_XXXXXXXXXX.p8 \
    --key-id   XXXXXXXXXX \
    --issuer   <ISSUER-UUID>
```

`continuum-notary` is the name you pass as `CONTINUUM_NOTARY_PROFILE`.

## 4. Build, sign, notarize, staple

```sh
CONTINUUM_SIGN_ID="Developer ID Application: Your Name (TEAMID)" \
CONTINUUM_NOTARY_PROFILE="continuum-notary" \
make macos
```

The script signs inside-out (dylibs + game libs, then `SDL2.framework`, then the
`xash3d` executable with the hardened runtime + `entitlements.plist`, then the
bundle), submits the zip to Apple, waits, staples the ticket onto the `.app`,
and re-zips. The resulting `dist/artifacts/continuum-macos-arm64.zip` passes
Gatekeeper on a clean machine. Verify a finished build with:

```sh
spctl -a -vvv -t install dist/macos/Continuum.app   # -> "accepted, source=Notarized Developer ID"
xcrun stapler validate dist/macos/Continuum.app
```

## Notes

- `entitlements.plist` sets `disable-library-validation` so the engine can load
  game-code dylibs (ours, or a user-added mod's) under the hardened runtime.
- If notarization is rejected, get the detail with:
  `xcrun notarytool log <submission-id> --keychain-profile continuum-notary`.
