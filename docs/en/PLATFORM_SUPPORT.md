# Platform support

This document defines what supported means for CocinaP on Android, iOS and
Windows. It separates implementation, compilation and physical device
validation.

## Support matrix

| Component | Platform | Requirement | Verifiable status |
|---|---|---:|---|
| Mobile app | Android | Android 8.0+ / API 26+ | Code, permissions and APK/AAB builds prepared |
| Mobile app | iOS | iOS 17.0+ | Code and CI build prepared; physical validation required |
| Local detection | Android | Camera available | ML Kit integrated; camera foreground service implemented; physical device validation pending |
| Local detection | iPhone | Camera available | ML Kit integrated; test on a physical iPhone |
| Local detection | Windows | Camera available | MoveNet/ONNX integrated; build and physical camera validation pending |
| IP camera | Android | ONVIF/RTSP or HTTP/MJPEG camera on LAN | ONVIF and RTSP implemented; physical compatibility matrix pending |
| IP camera | iOS | ONVIF/RTSP or HTTP/MJPEG camera on LAN | RTSP/MJPEG implemented; multicast discovery needs iPhone QA |
| Desktop app | Windows | Windows 10/11, Developer Mode and Visual Studio 2022 C++ workload | Flutter target implemented; build and physical validation pending |
| Remote camera | Windows + Android/iOS | Tailscale on both devices | Authenticated API implemented; end-to-end validation pending |

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
4. Validate camera, permissions, alarms, background camera service, local network and rotation. Background monitoring currently supports the phone camera only; IP-camera monitoring requires CocinaP to remain open.
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
On iPhone, camera capture and detection do not continue after CocinaP enters the
background. Continuous alerts with the app closed require detection on an
always-on host and push notifications; that integration is not implemented.

## Windows

Enable Windows Developer Mode and install Visual Studio 2022 with the
**Desktop development with C++** workload. Then run:

```powershell
cd cocinap_mobile
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

The Windows app uses the `camera_windows` plugin for webcam snapshots (about
one frame per second) and MoveNet Lightning through ONNX Runtime. IP camera
stream rates depend on the source. Validate both sources and remote Tailscale
access on Windows hardware before calling the target release-ready.

## Minimum test matrix

| Test | Android | iPhone | Windows | Acceptance criterion |
|---|---:|---:|---:|---|
| Installation from release artifact | Required | Required | Required | Starts without crashes or data loss |
| Camera permission | Required | Required | Required | Explained before request and safe when denied |
| Mobile/Windows camera detection | Required | Required | Required | Documented detection and no-detection scenarios pass |
| IP camera/RTSP/MJPEG | Required | Required | Required | Stream renders without blocking the UI |
| ONVIF discovery | Required for ONVIF cameras | Required for ONVIF cameras | Required for ONVIF cameras | Camera on same LAN; validate local-network permission/multicast on iPhone |
| Remote stream over Tailscale | Required | Required | Required | Authenticated video works off-LAN; no router port forwarding |
| Suspend/resume or PC sleep | Required | Required | Required | App resumes safely or reports unavailable camera |

## Approval criterion

A platform may be declared release-ready only when the build is reproducible,
all critical tests pass, the validation environment is recorded and known
limitations have an owner and correction plan.
