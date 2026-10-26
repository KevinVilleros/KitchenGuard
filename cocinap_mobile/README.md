# CocinaP Mobile

English | [Español](README.es.md)

Flutter mobile application for CocinaP, supporting Android and iPhone/iOS.

## Platform status

| Platform | Status |
|---|---|
| Android | Implemented; APK and AAB release builds are supported. |
| iOS / iPhone | Implemented; GitHub Actions produces an unsigned IPA. |

Code compatibility and automated builds do not replace physical-device validation.
See [platform support](../docs/en/PLATFORM_SUPPORT.md) before a release.

## Features

- Standalone phone or IP-camera monitoring.
- On-device person detection with TFLite.
- Local sound and vibration alerts.
- Live MJPEG camera dashboard.
- Real-time fire, smoke and person state when connected to the PC backend.
- mDNS, QR and manual server discovery.
- English and Spanish interface strings.
- Camera placement and first-use guidance.

## Screens

| Screen | Purpose |
|---|---|
| Monitoring | Standalone phone/IP-camera monitoring and person detection |
| Connect | mDNS, QR or manual backend connection |
| Camera | Live PC camera stream |
| Alarms | Real-time alarm history |
| Settings | Monitoring, camera source, alerts and language |

## Technology

- Flutter 3.32+
- Provider state management
- Shared Preferences and secure API-key storage
- HTTP and Server-Sent Events
- mDNS discovery
- Local notifications and background service
- TFLite and Google ML Kit detection
- Camera and MJPEG stream support

Firebase Cloud Messaging was removed from the mobile client. Notifications are
local and do not require Firebase configuration.

## Build Android

```bash
cd cocinap_mobile
flutter pub get
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

## Build iOS

```bash
cd cocinap_mobile
flutter pub get
flutter build ios --release --no-codesign
```

Without macOS, run the **Mobile Builds CocinaP** GitHub Actions workflow and
download the `CocinaP-iOS` artifact. Installation instructions are available in
[the iOS installation guide](../docs/INSTALL_IOS_WINDOWS.es.md).

## Source layout

```text
lib/
├── content/        Bilingual application strings
├── pages/          Application screens
├── providers/      Domain state management
├── services/       HTTP, storage, camera, detection and notifications
└── widgets/        Reusable components
```
