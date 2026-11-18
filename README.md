<div align="center">

# CocinaP

English | [Español](docs/es/ARCHITECTURE.md)

### Kitchen safety for Android, iPhone and Windows

**Unattended-kitchen monitoring with on-device person detection, phone cameras
or IP cameras, across Android, iOS and Windows.**

[![Flutter](https://img.shields.io/badge/Flutter-3.29+-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.2+-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![On-device AI](https://img.shields.io/badge/On--device_AI-ML_Kit_%7C_MoveNet-FF6F00?style=flat-square&logo=tensorflow&logoColor=white)](https://onnxruntime.ai/)
[![License](https://img.shields.io/badge/License-Commercial-red?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.2--pre-orange?style=flat-square)](CHANGELOG.md)

</div>

---

## What is CocinaP?

CocinaP is a Flutter app for **Android, iOS and Windows** that monitors a
kitchen and alerts the user when it appears unattended. It can use the device
camera or an IP camera and performs person detection locally: ML Kit Pose
Detection on Android/iOS and MoveNet Lightning through ONNX Runtime on Windows.
Images are not uploaded to a cloud service.

The local camera workflow remains available on mobile and Windows. Windows can
also serve its selected camera to the phone over a private Tailscale network
when the phone is away from home; monitoring must remain running on the PC.

## Features

| Capability | Detail |
|---|---|
| Standalone monitoring | Phone camera or IP camera monitoring |
| On-device detection | ML Kit on Android/iOS; MoveNet Lightning on Windows |
| IP camera support | Local ONVIF discovery; RTSP and HTTP/MJPEG streams |
| Monitoring timer | Configurable duration, pause and unattended alerts |
| Local alarms | Sound and vibration alerts |
| Remote Windows video | Authenticated MJPEG through private Tailscale Serve |
| First-use guide | Setup, camera placement and terms |
| Bilingual UI | English and Spanish |
| Android, iOS and Windows | Shared Flutter implementation |

## Requirements and support

| Platform | Requirement | Current status |
|---|---|---|
| Android | Android 8.0+ / API 26+ | Implemented; APK and AAB release builds supported |
| iOS / iPhone | iOS 17.0+ | Implemented; IPA CI build available and physical-device validation required |
| Windows | Windows 10/11, Developer Mode and Visual Studio 2022 with Desktop development with C++ | Flutter desktop target implemented; camera, runtime and Tailscale need Windows device validation |
| Network | Local WiFi for LAN cameras; Tailscale on PC and phone for remote video |

See the [platform support matrix](docs/en/PLATFORM_SUPPORT.md) for acceptance
criteria and the [iOS installation guide](docs/INSTALL_IOS_WINDOWS.es.md) for
cloud build and Sideloadly installation.

> **Pre-release:** network-camera compatibility and store-distribution checks
> are still in progress. ONVIF discovery only finds cameras that advertise
> ONVIF on the same local network; not every V380 Pro camera exposes ONVIF or
> RTSP. See the [camera compatibility and release checklist](docs/en/ROADMAP.md).

## Quick start

### Development

```bash
cd cocinap_mobile
flutter pub get
flutter run
```

For Windows desktop, enable Windows Developer Mode and install Visual Studio
2022 with the **Desktop development with C++** workload, then run
`flutter run -d windows`.

### Android release build

```bash
cd cocinap_mobile
flutter build apk --release
# Output: cocinap_mobile/build/app/outputs/flutter-apk/app-release.apk
```

### iOS release build

```bash
cd cocinap_mobile
flutter build ipa --release
```

GitHub Actions packages an unsigned IPA without a local Mac:
`Actions -> Mobile Builds CocinaP -> Run workflow`. Download the
`CocinaP-iOS` artifact and install it according to the
[iOS installation guide](docs/INSTALL_IOS_WINDOWS.es.md).

## Project structure

```
KitchenGuard/
├── cocinap_mobile/            # Flutter Android, iOS and Windows application
│   ├── lib/
│   │   ├── content/           # English/Spanish content
│   │   ├── pages/             # Application screens
│   │   ├── providers/         # Application state
│   │   ├── services/          # API, ONVIF, MJPEG, detection and alerts
│   │   └── widgets/           # Reusable components
│   ├── android/               # Android configuration
│   ├── ios/                   # iOS configuration
│   ├── assets/models/         # MoveNet ONNX model and notices
│   └── windows/               # Windows desktop runner
├── docs/                      # English and Spanish documentation
├── .github/workflows/         # Android, iOS and CodeQL automation
├── CHANGELOG.md
└── LICENSE
```

## Documentation

The complete documentation index is available in [docs/README.md](docs/README.md).
English is the primary repository language, with Spanish equivalents retained
under `docs/es/`.

| Document | Description |
|---|---|
| [Architecture](docs/en/ARCHITECTURE.md) | Components and data flows |
| [Installation](docs/en/INSTALLATION.md) | Development and build setup |
| [User guide](docs/en/USER_GUIDE.md) | Application usage |
| [API reference](docs/en/API.md) | Local and remote camera endpoints |
| [Development](docs/en/DEVELOPMENT.md) | Environment and conventions |
| [Testing and CI/CD](docs/en/TESTING.md) | Test strategy and workflows |
| [Platform support](docs/en/PLATFORM_SUPPORT.md) | Device support and release criteria |
| [Security](docs/en/SECURITY.md) | Threat model and practices |
| [Troubleshooting](docs/en/TROUBLESHOOTING.md) | Common problems and fixes |
| [Privacy policy](docs/legal/PRIVACY_POLICY.en.md) | Privacy and local processing |
| [Changelog](CHANGELOG.md) | Release history |
| [Contributing](CONTRIBUTING.md) | Contribution policy |
| [Security policy](SECURITY.md) | Vulnerability reporting |

## Privacy

In local mode, camera images are processed on the device. Optional remote
desktop video is transmitted over the configured private Tailscale network.
See the [privacy policy](docs/legal/PRIVACY_POLICY.en.md).

## License

CocinaP is commercial software. All rights reserved. This repository may not be
copied, modified or redistributed without written authorization. See
[LICENSE](LICENSE) for the complete terms.

## Contact

- Repository: [github.com/KevinVilleros/KitchenGuard](https://github.com/KevinVilleros/KitchenGuard)
- Issues: [GitHub Issues](https://github.com/KevinVilleros/KitchenGuard/issues)
- Developer: Kevin Villeros
