<div align="center">

# CocinaP

English | [Español](docs/es/ARCHITECTURE.md)

### Kitchen safety for Android and iPhone

**Unattended-kitchen monitoring with on-device person detection, phone cameras
or IP cameras, across Android and iOS.**

[![Flutter](https://img.shields.io/badge/Flutter-3.29+-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.2+-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![TFLite](https://img.shields.io/badge/TensorFlow_Lite-2.x-FF6F00?style=flat-square&logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![License](https://img.shields.io/badge/License-Commercial-red?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.1-orange?style=flat-square)](CHANGELOG.md)

</div>

---

## What is CocinaP?

CocinaP is a Flutter app for **Android and iOS** that monitors a kitchen and
alerts the user when it appears unattended. It can use the phone camera or an
IP camera and performs person detection **on the device** with TensorFlow Lite,
without uploading images to a cloud service.

The app can also connect to an optional CocinaP PC backend over WiFi to display
PC camera footage, fire and smoke alarms, and remote configuration controls.

## Features

| Capability | Detail |
|---|---|
| Standalone monitoring | Phone camera or IP camera monitoring |
| On-device detection | SSD MobileNet V2/TFLite without cloud processing |
| IP camera support | HTTP/MJPEG home and security camera streams |
| Monitoring timer | Configurable duration, pause and unattended alerts |
| Local alarms | Sound and vibration alerts |
| PC connection | QR scanning, mDNS discovery and manual configuration |
| First-use guide | Setup, camera placement and terms |
| Bilingual UI | English and Spanish |
| Android and iOS | Shared Flutter implementation |

## Requirements and support

| Platform | Requirement | Current status |
|---|---|---|
| Android | Android 8.0+ / API 26+ | Implemented; APK and AAB release builds supported |
| iOS / iPhone | iOS 17.0+ | Implemented; IPA CI build available and physical-device validation required |
| Connected PC | Windows 10/11 and Python 3.10+ | Optional archived backend |
| Network | WiFi on the same subnet | Required only for connected mode |

See the [platform support matrix](docs/en/PLATFORM_SUPPORT.md) for acceptance
criteria and the [iOS installation guide](docs/INSTALL_IOS_WINDOWS.es.md) for
cloud build and Sideloadly installation.

## Quick start

### Development

```bash
cd cocinap_mobile
flutter pub get
flutter run
```

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
├── cocinap_mobile/            # Flutter mobile application
│   ├── lib/
│   │   ├── content/           # English/Spanish content
│   │   ├── pages/             # Application screens
│   │   ├── providers/         # Application state
│   │   ├── services/          # API, MJPEG, mDNS, TFLite and alerts
│   │   └── widgets/           # Reusable components
│   ├── android/               # Android configuration
│   ├── ios/                   # iOS configuration
│   └── assets/models/         # TFLite model assets
├── yolo/                      # Optional archived Python/YOLO backend
├── docs/                      # English and Spanish documentation
├── .github/workflows/         # Android, iOS, Python and CodeQL automation
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
| [API reference](docs/en/API.md) | Backend endpoints |
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

Camera images are processed on the device. The on-device detection model does
not upload images to external servers. See the
[privacy policy](docs/legal/PRIVACY_POLICY.en.md).

## License

CocinaP is commercial software. All rights reserved. This repository may not be
copied, modified or redistributed without written authorization. See
[LICENSE](LICENSE) for the complete terms.

## Contact

- Repository: [github.com/KevinVilleros/KitchenGuard](https://github.com/KevinVilleros/KitchenGuard)
- Issues: [GitHub Issues](https://github.com/KevinVilleros/KitchenGuard/issues)
- Developer: Kevin Villeros
