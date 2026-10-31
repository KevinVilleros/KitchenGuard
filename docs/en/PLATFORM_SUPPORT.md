# Platform support

This document defines what supported means for CocinaP on Android, iOS and the
optional Windows backend. It separates implementation, compilation and physical
device validation.

## Support matrix

| Component | Platform | Requirement | Verifiable status |
|---|---|---:|---|
| Mobile app | Android | Android 8.0+ / API 26+ | Code, permissions and APK/AAB builds prepared |
| Mobile app | iOS | iOS 17.0+ | Code and CI build prepared; physical validation required |
| Local detection | Android | Camera available | TFLite model integrated; test with compatible devices |
| Local detection | iPhone | Camera available | Model and ML Kit plugin integrated; test on a physical iPhone |
| IP camera | Android | ONVIF/RTSP or HTTP/MJPEG camera on LAN | ONVIF and RTSP implemented; physical compatibility matrix pending |
| IP camera | iOS | ONVIF/RTSP or HTTP/MJPEG camera on LAN | RTSP/MJPEG implemented; multicast discovery needs iPhone QA |
| Optional backend | Windows | Windows 10/11, Python 3.10+ | Packaging and Python CI available |
| Connected mode | Android/iOS | Shared local network | Requires mDNS, QR or manual URL validation on both platforms |

## Android

Release configuration is located at `cocinap_mobile/android/app/build.gradle.kts`.
The manifest declares Internet, camera, foreground service, notifications and
boot-related permissions. Before publishing a release:

**Current blocker:** the `release` build type still uses the `debug` signing
key. Do not distribute APK/AABs built with that key; configure and validate a
production signing key outside the repository.

1. Run `flutter analyze` and `flutter test`.
2. Build `flutter build apk --release` and `flutter build appbundle --release`.
3. Install the APK on a clean physical device.
4. Validate camera, permissions, alarms, background behavior, local network and rotation.
5. Record the Android model, OS version and result in the QA matrix.

## iOS / iPhone

Local compilation requires macOS with Xcode. From Windows,
`.github/workflows/ios.yml` can generate an unsigned `.ipa` through GitHub
Actions. Before publishing a release:

1. Run the workflow manually or through changes under `cocinap_mobile/**`.
2. Confirm that the job finishes without errors and download `CocinaP-iOS`.
3. Install the IPA with Sideloadly or a valid distribution profile.
4. Validate camera, local network, notifications, background behavior and screen
   orientation changes on at least one physical iPhone.
5. Record the device model, iOS version and result in the QA matrix.

An unsigned IPA is not a production distribution artifact. A free Apple account
may impose an expiration period of approximately seven days.

## Minimum test matrix

| Test | Android | iPhone | Acceptance criterion |
|---|---:|---:|---|
| Installation from release artifact | Required | Required | Starts without crashes or data loss |
| Camera permission | Required | Required | Explained before request and safe when denied |
| Local network/notification permissions | As applicable | Required | Function explains denial and preserves a valid state |
| Mobile camera detection | Required | Required | Documented detection and no-detection scenarios pass |
| IP camera/MJPEG | Required | Required | Stream renders without blocking the UI |
| ONVIF discovery | Required for ONVIF cameras | Required for ONVIF cameras | Camera on same LAN; validate local-network permission/multicast on iPhone |
| IP camera/RTSP | Required | Required | Stable video and detection with valid credentials |
| Backend connection | Recommended | Recommended | QR, mDNS and manual connection work |
| Screen rotation | Required | Required | UI does not lose state or cut controls |
| Suspend/resume | Required | Required | App resumes safely or stops in a controlled state |

## Approval criterion

A platform may be declared release-ready only when the build is reproducible,
all critical tests pass, the validation environment is recorded and known
limitations have an owner and correction plan.
