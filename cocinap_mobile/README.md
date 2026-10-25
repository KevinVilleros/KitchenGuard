# CocinaP Mobile — App de monitoreo de cocina

Aplicación móvil Flutter compatible con Android y iOS para el sistema de seguridad CocinaP.

## Estado de plataforma

| Plataforma | Estado |
|---|---|
| Android | Implementada y distribuible como APK/AAB. Requiere pruebas de instalación y permisos por dispositivo y release. |
| iOS / iPhone | Implementada con build de CI y configuración de permisos. Requiere compilación firmada o `.ipa` y validación física en iPhone. |

La compatibilidad de código, un workflow de CI y una configuración de plataforma no reemplazan una matriz de pruebas en dispositivos reales.

## Características

- **Monitoreo independiente** con la cámara del móvil o una cámara IP
- Detección de personas **on-device** con TFLite (SSD MobileNet V2 / COCO)
- Alerta local (sonido + vibración) si la cocina queda desatendida
- Dashboard en vivo con stream MJPEG de la cámara del servidor
- Estado de detección en tiempo real (fuego, humo, personas)
- Alarmas en tiempo real vía Server-Sent Events (SSE)
- Auto-descubrimiento del servidor vía mDNS
- Conexión por código QR, manual o automática
- Manual, guía de cámaras y términos en español e inglés
- Guía de instalación/colocación de cámara en el primer uso

## Pantallas

| Pantalla | Descripción |
|---|---|
| **Monitoreo** | Modo independiente: cámara móvil/IP + detección de personas |
| **Conectar** | Auto-descubrimiento mDNS, QR o conexión manual |
| **Cámara** | Video en vivo del servidor + indicadores de estado |
| **Alarmas** | Historial de alarmas en tiempo real |
| **Ajustes** | Preferencias, fuente de cámara, monitoreo y ayuda |

## Stack

- **Framework:** Flutter 3.32+
- **Estado:** Provider
- **HTTP:** `http` package
- **mDNS:** `multicast_dns`
- **Notificaciones locales:** flutter_local_notifications
- **Detección:** tflite_flutter (`ssd_mobilenet_v2_coco.tflite`, entrada uint8)
- **Background:** flutter_background_service

> **Nota:** se eliminó Firebase (FCM) para permitir compilar sin
> `google-services.json`. Las notificaciones locales funcionan.

## Compilar Android

```bash
cd cocinap_mobile
flutter pub get
flutter build apk --release
```

APK en `build/app/outputs/flutter-apk/app-release.apk`.

## Compilar iOS (sin Mac local)

Acción de GitHub que compila el `.ipa` en la nube: en `Actions → iOS Build
CocinaP → Run workflow`. Descarga el artefacto `CocinaP-iOS` e instálalo con
Sideloadly (ver `docs/INSTALL_IOS_WINDOWS.es.md`).

## Estructura

```
lib/
├── main.dart                    # Entry point, navegación, primer uso y tour
├── content/
│   └── content.dart             # Manual, guía, objetivos e info (ES/EN)
├── providers/
│   ├── server_provider.dart     # Estado de conexión + mDNS
│   ├── alarms_provider.dart     # Estado de alarmas SSE
│   ├── standalone_provider.dart # Monitoreo independiente
│   └── tour_controller.dart     # Estado del tour guiado de la interfaz
├── services/
│   ├── api_service.dart         # Llamadas HTTP a API REST
│   ├── discovery_service.dart   # mDNS discovery
│   ├── mjpeg_service.dart       # Parser de stream MJPEG
│   ├── person_detector.dart     # Detección TFLite on-device
│   ├── background_service.dart  # Servicio superior (notificaciones)
│   └── settings_service.dart    # SharedPreferences
├── pages/
│   ├── home_page.dart           # Inicio: dashboard gráfico y objetivos
│   ├── onboarding_page.dart     # Onboarding de primer uso + interfaz
│   ├── standalone_page.dart     # Monitoreo independiente
│   ├── camera_install_guide_page.dart  # Guía de colocación de cámara
│   ├── discovery_page.dart      # Pantalla de conexión
│   ├── dashboard_page.dart      # Cámara del PC en vivo
│   ├── alarms_page.dart         # Historial de alarmas
│   ├── ip_camera_page.dart      # Fuente de cámara móvil/IP
│   ├── help_page.dart           # Manual, guía y términos
│   └── settings_page.dart       # Preferencias
└── widgets/
    ├── graphical.dart           # Anillos, tarjetas y timeline gráficos
    ├── tour_overlay.dart        # Coach marks del tour de interfaz
    ├── mjpeg_viewer.dart        # Widget MJPEG player
    └── status_card.dart         # Card de indicador
```
> Estado de CI: el build iOS se genera via GitHub Actions (workflow \iOS Build CocinaP\). Ver \docs/INSTALL_IOS_WINDOWS.es.md\ para instalarlo con Sideloadly.
