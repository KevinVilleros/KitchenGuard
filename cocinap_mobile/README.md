# CocinaP Mobile — App de Monitoreo de Cocina

App compañera (Android e iOS) para el sistema CocinaP de seguridad en la cocina.

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
├── main.dart                    # Entry point, guía de primer uso
├── content/
│   └── content.dart             # Manual, guía y términos (ES/EN)
├── providers/
│   ├── server_provider.dart     # Estado de conexión + mDNS
│   ├── alarms_provider.dart     # Estado de alarmas SSE
│   ├── config_provider.dart     # Estado de configuración remota
│   └── standalone_provider.dart # Monitoreo independiente
├── services/
│   ├── api_service.dart         # Llamadas HTTP a API REST
│   ├── discovery_service.dart   # mDNS discovery
│   ├── mjpeg_service.dart       # Parser de stream MJPEG
│   ├── person_detector.dart     # Detección TFLite on-device
│   ├── background_service.dart  # Servicio superior (notificaciones)
│   └── settings_service.dart    # SharedPreferences
├── pages/
│   ├── standalone_page.dart     # Monitoreo independiente
│   ├── camera_install_guide_page.dart  # Guía de colocación (1er uso)
│   ├── discovery_page.dart      # Pantalla de conexión
│   ├── dashboard_page.dart      # Dashboard en vivo
│   ├── alarms_page.dart         # Historial de alarmas
│   ├── config_page.dart         # Configuración remota (no navegable)
│   ├── ip_camera_page.dart      # Fuente de cámara móvil/IP
│   ├── help_page.dart           # Manual, guía y términos
│   └── settings_page.dart       # Preferencias
└── widgets/
    ├── mjpeg_viewer.dart        # Widget MJPEG player
    └── status_card.dart         # Card de indicador
```