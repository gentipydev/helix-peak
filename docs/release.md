# Releasing to the App Store and Google Play

What a store build needs that a development build does not. Written in the security
review of 2026-11-13. The backend's side, every limit on what the public service may
cost, is `../helix-peak-backend/SECURITY.md`.

## Decide once, before the first upload

These cannot be changed after a store has published the app.

**The app's id.** It is still Flutter's placeholder on both platforms:
`com.example.helixpeek`. Google Play refuses `com.example`. Choose a reverse-DNS name you
control (for example `io.github.<account>.helixpeek`) and set it in:

- `android/app/build.gradle.kts`: `namespace` and `applicationId`. Move
  `MainActivity.kt` to the matching package directory and change its `package` line.
- `ios/Runner.xcodeproj` (Runner target → Signing & Capabilities): `PRODUCT_BUNDLE_IDENTIFIER`
  for Runner, and `<id>.RunnerTests` for RunnerTests.

**The Android upload key.** Release builds are signed with the key that
`android/key.properties` names. Without that file they fall back to the debug key, so
`flutter run --release` keeps working, but Google Play refuses a debug-signed upload.
Make the key once:

```sh
keytool -genkeypair -v -keystore ~/helixpeek-upload.jks -keyalg RSA -keysize 4096 \
        -validity 10000 -alias upload
```

Then write `android/key.properties`:

```properties
storeFile=/Users/<you>/helixpeek-upload.jks
storePassword=<the store password>
keyAlias=upload
keyPassword=<the key password>
```

`storeFile` may be absolute, or relative to `android/app/`. `key.properties`, `*.jks` and
`*.keystore` are git-ignored. Keep the keystore and both passwords in a password manager
or another backup outside the repository. Enrol in **Play App Signing** when you create
the app: Google then holds the key that signs what users install, and a lost upload key
can be reset.

## Build

```sh
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/android
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios
```

`--obfuscate` renames the app's Dart symbols in the binary. The app holds no secret
(below), so this is ordinary hardening, not what keeps anything safe. Keep each release's
`build/symbols/` (`build/` is git-ignored, so copy it somewhere kept): without it, the
stores' crash reports cannot be read.

## What the app holds, and sends

- **No secret.** The only bundled configuration is `.env`: `API_BASE_URL` and
  `API_TIMEOUT_MS`. Anything put in `.env` ships inside the app, where anyone can read
  it, so never add a key or token there. The backend needs none from the app.
- **HTTPS only.** Android blocks cleartext traffic (no `usesCleartextTraffic`, target SDK
  28+). iOS's App Transport Security is on, with no exceptions in `Info.plist`.
- **One identifier.** `InstallId` (`lib/core/catalog/install_id.dart`) is 128 random bits
  made on first use and kept in the app's support directory. It goes with each build
  request, so that only the phone that asked can stop, keep or discard that build, and
  so the service can cap one install's builds a day. It names nobody, is linked to
  nothing, and is never used to track. Deleting the app deletes it.
- **Nothing else.** No accounts, no analytics, no advertising, no crash-reporting SDK, no
  location, no contacts. The track cache (up to 200 MB of public scientific data) stays on
  the device.
- **Links.** The only deep link is `helixpeek://open/gene/<slug>`. It opens a protein's
  page by name and nothing more.

## The stores' privacy answers

These follow from the facts above. Re-check them whenever the app starts sending
anything new.

**App Store privacy label.** Data used to track you: none. Data not linked to you:
*Identifiers → Device ID*, for *App Functionality*. `ios/Runner/PrivacyInfo.xcprivacy`
declares the same, together with the app's one required-reason API: file timestamps
(`C617.1`), read and set on its own cache to evict the least recently read file.

**Google Play Data safety.** Collected: *Device or other IDs* (the install id). Not
shared. Encrypted in transit. Collection is required, not optional. Purposes: *App
functionality* and *Fraud prevention, security, and compliance*. There is no account, so
there is nothing to delete beyond uninstalling. A build a phone stopped can be
discarded from that phone.

**A privacy policy URL** is required by both stores. It must state the facts in "What the
app holds, and sends". The backend keeps the install id with each build request it
records; Supabase (database and storage), Render (the API) and Modal (the builds) are its
processors.

## Before each upload

- `flutter analyze` and `flutter test` green.
- The build number in `pubspec.yaml` raised.
- The backend healthy: `curl https://helix-peak-backend.onrender.com/health`.
