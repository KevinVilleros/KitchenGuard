<div align="center">

# CocinaP

### App móvil de seguridad para la cocina

**Monitoreo de cocina desatendida con detección de personas on-device,
cámara del móvil o cámara IP, en Android e iOS.**

[![Flutter](https://img.shields.io/badge/Flutter-3.29+-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.2+-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![TFLite](https://img.shields.io/badge/TensorFlow_Lite-2.x-FF6F00?style=flat-square&logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![License](https://img.shields.io/badge/License-Comercial-red?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.1-orange?style=flat-square)](CHANGELOG.md)

</div>

---

## Qué es CocinaP

CocinaP es una app Flutter para **Android e iOS** que vigila tu cocina y te
avisa si queda desatendida. Usa la cámara del teléfono o una cámara IP y
detecta personas **en el propio dispositivo** con un modelo TensorFlow Lite
(no requiere PC). Es la tecnología principal del proyecto y funciona en todas
las plataformas.

Si además tienes un ordenador con CocinaP, la app puede conectarse a él por
WiFi para ver la cámara del PC, las alarmas (fuego/humo) y controlar la
configuración de forma remota.

## Características

| Capacidad | Detalle |
|---|---|
| **Modo independiente** | Monitorea la cocina con la cámara del móvil o una cámara IP |
| **Detección on-device** | Personas con SSD MobileNet v2 (TFLite), sin PC ni nube |
| **Cámara IP (MJPEG)** | Conéctate a cámaras de hogar/seguridad por HTTP/MJPEG |
| **Temporizador de monitoreo** | Plazo configurable con pausa y alerta si nadie está presente |
| **Alarmas locales** | Aviso con sonido y vibración cuando la cocina queda desatendida |
| **Conexión al PC** | Escaneo de QR, auto-descubrimiento (mDNS) y conexión manual |
| **Guía de primer uso** | Manual de uso, guía de cámaras y colocación, y términos |
| **Bilingüe** | Español e inglés |
| **Android + iOS** | Un mismo código para las dos plataformas |

## Requisitos

### Android
- Android 8.0+ (API 26+)

### iOS
- iOS 17.0+
- Compilación/firma: ver [Guía de instalación iOS desde Windows](docs/INSTALL_IOS_WINDOWS.es.md)

### Red
- WiFi en la misma subred que la PC (solo para el modo conectado)

## Inicio rápido

### Desarrollo

```bash
cd cocinap_mobile
flutter pub get
flutter run
```

### Compilar APK (Android)

```bash
cd cocinap_mobile
flutter build apk --release
# Output: cocinap_mobile/build/app/outputs/flutter-apk/app-release.apk
```

### Compilar app iOS

```bash
cd cocinap_mobile
flutter build ipa --release
```

Sin Mac, la compilación de iOS se hace en la nube con GitHub Actions
(workflow **"iOS Build CocinaP"**) y luego se instala el `.ipa` en el iPhone
con Sideloadly. Pasos detallados:
[docs/INSTALL_IOS_WINDOWS.es.md](docs/INSTALL_IOS_WINDOWS.es.md).

## Estructura del Proyecto

```
KitchenGuard/
├── cocinap_mobile/            # App Flutter (tecnología principal)
│   ├── lib/
│   │   ├── content/           #   Manual, guía de cámaras y términos (ES/EN)
│   │   ├── pages/             #   Monitoreo, Conectar, Cámara, Alarmas, Ajustes
│   │   ├── providers/         #   Estado: Server, Alarmas, Config, Standalone
│   │   ├── services/          #   API, MJPEG, mDNS, TFLite, notificaciones
│   │   └── widgets/           #   Componentes reutilizables
│   ├── android/               #   Config Android
│   ├── ios/                   #   Config iOS
│   └── assets/models/         #   Modelo TFLite (SSD MobileNet v2 COCO)
├── yolo/                      # Backend Python/YOLO archivado (ver yolo/README.md)
├── docs/                      # Documentación general y legal
│   ├── INSTALL_IOS_WINDOWS.es.md
│   └── legal/                 #   Política de privacidad (ES/EN)
├── .github/workflows/         # CI: iOS build + Python CI (yolo)
├── CHANGELOG.md
└── LICENSE
```

## Documentación

| Documento | Descripción |
|---|---|
| [Instalación iOS desde Windows](docs/INSTALL_IOS_WINDOWS.es.md) | Compilar en la nube e instalar con Sideloadly |
| [Política de privacidad](docs/legal/PRIVACY_POLICY.es.md) | Privacidad y procesamiento local |
| [Backend YOLO](yolo/README.md) | Backend Python/YOLO archivado |
| [Changelog](CHANGELOG.md) | Historial de versiones |
| [Contribuir](CONTRIBUTING.md) | Guía para colaboradores |
| [Seguridad](SECURITY.md) | Reporte de vulnerabilidades |

## Privacidad

Las imágenes de las cámaras se procesan **en el dispositivo** y no se suben a
servidores externos. El modelo de detección se ejecuta localmente. Ver
[docs/legal/PRIVACY_POLICY.es.md](docs/legal/PRIVACY_POLICY.es.md).

## Licencia

**CocinaP** es un producto comercial. Todos los derechos reservados. Este
software no puede ser copiado, modificado o distribuido sin autorización
expresa del titular. Ver [LICENSE](LICENSE) para los términos completos.

## Contacto

- **Repositorio:** [github.com/KevinVilleros/KitchenGuard](https://github.com/KevinVilleros/KitchenGuard)
- **Issues:** [GitHub Issues](https://github.com/KevinVilleros/KitchenGuard/issues)
- **Desarrollador:** Kevin Villeros
