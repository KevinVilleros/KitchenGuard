# Testing & CI/CD — CocinaP

Test strategy and continuous integration/delivery automation for the project.

---

## 1. Test strategy

| Layer | Tool | Location | Covers |
|---|---|---|---|
| Flutter app | `flutter_test` | `cocinap_mobile/test/` | Widgets, detector parsing, remote API |
| Static analysis | `flutter analyze` | `cocinap_mobile/` | Lint and types |

---

## 2. Mobile app tests

```bash
cd cocinap_mobile
flutter test
```

A smoke test is included in `test/widget_test.dart`: it verifies the app starts.

Run a single test:

```bash
flutter test test/widget_test.dart
```

Focused network/camera tests:

```bash
flutter test test/mjpeg_frame_parser_test.dart test/onvif_camera_service_test.dart
```

These cover MJPEG frame parsing and ONVIF response filtering to accept local
endpoints and reject remote targets or URLs with embedded credentials. They do
not replace physical testing of ONVIF negotiation, authentication, RTSP video,
per-model compatibility or network-loss recovery.

Coverage:

```bash
flutter test --coverage
# generates coverage/lcov.info
```

### Android production signing

The `release` build type no longer uses the debug key. Without signing
configuration, Gradle produces an unsigned `release` artifact and prints a
warning; that artifact cannot be uploaded to Google Play.

1. Create and store an upload key outside the repository. Keep it secure and
   retain a backup; losing it can prevent future app updates.
2. Create `cocinap_mobile/android/key.properties` with `storeFile`,
   `storePassword`, `keyAlias` and `keyPassword`. `storeFile` is relative to
   `cocinap_mobile/android`; for example, `upload-keystore.jks` if the file is
   stored there.
3. Keep both `key.properties` and the `.jks` or `.keystore` file out of Git.
   Never share passwords or keys in source code, chat or CI logs.
4. Build the AAB with `flutter build appbundle --release` and verify its
   signature before uploading it to Play Console.

---

## 3. Windows and remote access tests

```bash
cd cocinap_mobile
flutter test test/windows_person_detector_test.dart test/remote_camera_server_test.dart test/remote_desktop_service_test.dart
```

These tests cover MoveNet output parsing, API-key authentication, camera
availability responses and remote-address validation. They do not replace a
Windows build, webcam/RTSP device testing, or an end-to-end Tailscale test.

---

## 4. Static analysis and formatting

```bash
# Mobile app
cd cocinap_mobile
flutter analyze
dart format --set-exit-if-changed .

```

---

## 5. Continuous integration (GitHub Actions)

Workflows in `.github/workflows/`:

### 5.1 `ios.yml` — "iOS Build CocinaP"

| Aspect | Detail |
|---|---|
| Trigger | push to `main`/`master` touching `cocinap_mobile/**` or `.github/workflows/ios.yml`; or manual (`workflow_dispatch`) |
| Runners | `ubuntu-latest` for Android and `macos-latest` for iOS |
| Jobs | `validate-mobile` (analyze and tests), `build-android` (unsigned APK), `build-unsigned` (unsigned `.ipa`) and `build-signed` (optional) |
| Artifacts | `CocinaP-Android-unsigned` (contains `app-release.apk`) and `CocinaP-iOS` (contains `CocinaP-unsigned.ipa`) |

Both platform builds depend on `validate-mobile`. The workflow runs
`flutter analyze` and `flutter test` before producing platform artifacts.

### Android

The `build-android` job waits for validation, installs Java 17, sets up stable
Flutter, fetches dependencies and runs `flutter build apk --release`. Android
production signing is not configured in this workflow, so it produces an
unsigned APK that is not ready for store distribution. The
`CocinaP-Android-unsigned` artifact is published when that build succeeds, even
if a later iOS build fails.

Main Android job steps:

1. `checkout`.
2. `actions/setup-java` (Java 17).
3. `subosito/flutter-action` (stable channel).
4. `flutter pub get`.
5. `flutter build apk --release`.
6. Upload the unsigned APK artifact.

The `build-unsigned` job builds and packages the iOS app as
`CocinaP-unsigned.ipa`.

The `build-signed` job only signs when the secrets `IOS_CERTIFICATE`,
`IOS_CERTIFICATE_PASSWORD` and `IOS_PROVISIONING_PROFILE` are set; otherwise it
is skipped.

---

## 6. Continuous delivery (releases)

### Mobile app

- **Android:** `flutter build appbundle --release` produces the AAB for Google
  Play.
- **iOS:** the `.ipa` is produced in CI; it is distributed via Sideloadly (free
  account: expires after 7 days) or TestFlight/App Store with signing.

### Windows desktop

- Requires Windows Developer Mode and Visual Studio 2022 with **Desktop
  development with C++**.
- Build with `flutter build windows --release`; the repository does not
  currently publish a Windows CI artifact.

---

## 7. Versioning

- **Semantic Versioning** is followed (`MAJOR.MINOR.PATCH`).
- The app version lives in `cocinap_mobile/pubspec.yaml`.
- Changes are recorded in [CHANGELOG.md](../CHANGELOG.md) (Keep a Changelog
  format).

---

## 8. Pre-release checklist

- [ ] `flutter analyze` clean.
- [ ] `flutter test` green.
- [ ] APK and IPA reproducible from documented artifacts.
- [ ] Android and iPhone matrix completed on physical devices.
- [ ] Windows release build and camera/detector tested on Windows hardware.
- [ ] Real ONVIF, RTSP and MJPEG camera matrix tested and published; record
  incompatible models and negative test results.
- [ ] Review libmpv, FFmpeg/codec and native dependency licenses/notices before
  commercial distribution.
- [ ] Configure production signing; do not use the `debug` key.
- [ ] Complete and legally review the privacy policy, publisher identity and
  app-store listings.
- [ ] Camera, local-network and background permissions tested on-device.
- [ ] Known defects include an owner, impact and correction plan.
- [ ] Version bump in `pubspec.yaml`.
- [ ] New entry in `CHANGELOG.md`.
- [ ] iOS workflow completed successfully.
- [ ] `.ipa` artifact verified.

---

See also: [Development guide](DEVELOPMENT.md), [Installation](INSTALLATION.md).
