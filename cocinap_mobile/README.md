# CocinaP Mobile — App de Monitoreo Remoto

App companion para Android que se conecta al servidor CocinaP en la PC.

## Características

- Dashboard en vivo con stream MJPEG de la cámara
- Estado de detección en tiempo real (fuego, humo, personas)
- Alarmas push via Server-Sent Events (SSE)
- Configuración remota de parámetros de detección
- Auto-descubrimiento del servidor via mDNS
- Notificaciones push FCM (Firebase) — opcional
- Foreground service para alarmas en background
- Conexión automática al iniciar

## Pantallas

| Pantalla | Descripción |
|---|---|
| **Discovery** | Auto-descubrimiento mDNS o conexión manual |
| **Dashboard** | Video en vivo + indicadores de estado |
| **Alarmas** | Historial de alarmas en tiempo real |
| **Configuración** | Ajuste remoto de parámetros de detección |
| **Ajustes** | Preferencias de conexión |

## Stack

- **Framework:** Flutter 3.29+
- **Estado:** Provider
- **HTTP:** `http` package
- **mDNS:** `multicast_dns`
- **Notificaciones:** Firebase Messaging + flutter_local_notifications
- **Background:** flutter_background_service

## Compilar

```bash
cd cocinap_mobile
flutter pub get
flutter run                      # debug en dispositivo
flutter build apk --debug        # APK debug
flutter build apk --release      # APK release (requiere keystore)
```

## Estructura

```
lib/
├── main.dart                    # Entry point con inicialización
├── providers/
│   ├── server_provider.dart     # Estado de conexión + mDNS
│   ├── alarms_provider.dart     # Estado de alarmas SSE
│   └── config_provider.dart     # Estado de configuración remota
├── services/
│   ├── api_service.dart         # Llamadas HTTP a API REST
│   ├── discovery_service.dart   # mDNS discovery
│   ├── mjpeg_service.dart       # Parser de stream MJPEG
│   ├── fcm_service.dart         # Firebase Cloud Messaging
│   ├── background_service.dart  # Foreground service
│   └── settings_service.dart    # SharedPreferences
├── pages/
│   ├── discovery_page.dart      # Pantalla de conexión
│   ├── dashboard_page.dart      # Dashboard en vivo
│   ├── alarms_page.dart         # Historial de alarmas
│   ├── config_page.dart         # Configuración remota
│   └── settings_page.dart       # Preferencias
└── widgets/
    ├── mjpeg_viewer.dart        # Widget MJPEG player
    └── status_card.dart         # Card de indicador
```
