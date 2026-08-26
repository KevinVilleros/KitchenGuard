# CocinaP Mobile App - Implementation Plan

## Architecture
```
┌──────────────────────┐     REST + MJPEG + SSE      ┌──────────────────┐
│  Windows PC (Server)  │ ◄────────────────────────── │  Flutter App     │
│                       │   HTTP (LAN/WiFi)           │  (Android + iOS) │
│  - webui.py           │                             │                  │
│    - MJPEG /api/stream│                             │  - Dashboard     │
│    - SSE /api/events  │                             │  - Video en vivo │
│    - mDNS zeroconf    │                             │  - Alarmas push  │
│    - FCM push         │                             │  - Config remoto │
│    - REST API         │                             └──────────────────┘
└──────────┬────────────┘
           │ firebase-admin SDK
           ▼
         FCM (Firebase Cloud Messaging)
           │
     ┌─────┴─────┐
     ▼           ▼
  Android      iOS
  (FCM SDK)   (FCM→APNs)
```

## Backend Changes (Windows)

### 1. `cocinap/config.py` — Add settings
```python
WEB_PORT = 8080
ENABLE_FCM = False
FCM_KEY_FILE = os.path.join(_APP_DATA, "firebase-key.json")
FCM_TOKENS = []
```
- Add `"WEB_PORT"`, `"ENABLE_FCM"` to `_CONFIG_KEYS`
- `save_config()` includes `FCM_TOKENS` list
- `load_config()` restores `FCM_TOKENS`

### 2. `cocinap/detector/runner.py` — Expose raw frame
- Add `_last_frame` attribute stored on each detection cycle
- Add `last_frame` property returning a copy
- Thread-safe via existing lock

### 3. `cocinap/engine.py` — Wire WebUI with frame + FCM
```python
def __init__(self, get_frame_cb=None, web_port=None):
    ...
    self.webui = WebUI(
        port=web_port or 8080,
        get_frame_cb=lambda: self.runner.last_frame,
    ) if web_port is not None else None

def analyze(self, dets):
    ...
    if trigger and self.webui:
        self.webui.send_fcm(alerts)  # push to mobile
```

### 4. `cocinap/webui.py` — Major rewrite

#### New endpoints:
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/stream` | MJPEG (multipart/x-mixed-replace) at ~15 FPS |
| GET | `/api/events` | SSE stream for real-time alarm push |
| GET | `/api/info` | Server metadata (version, uptime, IPs) |
| POST | `/api/register_token` | Register FCM device token |
| POST | `/api/unregister_token` | Remove FCM device token |

#### WebUI class changes:
- Constructor: new `get_frame_cb` param for frame access
- `start()`: init mDNS zeroconf + ThreadingHTTPServer
- `stop()`: unregister mDNS
- `send_fcm(alerts)`: send push via firebase-admin to all registered tokens
- `push_status()`: also broadcast via SSE

#### MJPEG stream logic:
```python
def _handle_stream(self):
    self.send_response(200)
    self.send_header("Content-Type", "multipart/x-mixed-replace;boundary=frame")
    self.end_headers()
    while not self.server.webui._stopped:
        frame = self.server.webui.get_frame_cb()
        if frame is not None:
            _, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            self.wfile.write(b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + jpeg.tobytes() + b"\r\n")
        time.sleep(0.066)
```

#### SSE logic:
```python
def _handle_events(self):
    self.send_response(200)
    self.send_header("Content-Type", "text/event-stream")
    self.send_header("Cache-Control", "no-cache")
    self.end_headers()
    # connection kept open, server pushes data: {...}\n\n on each alarm
```

#### mDNS via python-zeroconf:
```python
from zeroconf import Zeroconf, ServiceInfo

self._zc = Zeroconf()
self._zc_info = ServiceInfo(
    "_cocinap._tcp.local.",
    f"CocinaP_{id}._cocinap._tcp.local.",
    port=port,
    properties={"version": "1.0.0"}
)
self._zc.register_service(self._zc_info)
```

#### FCM via firebase-admin:
```python
import firebase_admin
from firebase_admin import credentials, messaging

def send_fcm(self, alerts):
    if not cfg.ENABLE_FCM or not cfg.FCM_TOKENS:
        return
    if not firebase_admin._apps:
        cred = credentials.Certificate(cfg.FCM_KEY_FILE)
        firebase_admin.initialize_app(cred)
    for token in cfg.FCM_TOKENS:
        try:
            messaging.send(messaging.Message(
                notification=messaging.Notification(
                    title="CocinaP - Alarma",
                    body=alerts[0]["message"],
                ),
                data={"type": alerts[0]["type"], "severity": alerts[0]["severity"]},
                token=token,
            ))
        except Exception as e:
            print(f"[fcm] Error sending to {token[:16]}...: {e}")
```

## Flutter App

### pubspec.yaml dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  provider: ^6.1.0
  shared_preferences: ^2.3.0
  multicast_dns: ^0.3.0
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
  flutter_local_notifications: ^18.0.0
```

### File structure
```
cocinap_mobile/lib/
├── main.dart                    # runApp, providers, FCM init
├── services/
│   ├── api_service.dart         # HTTP client for all REST endpoints
│   ├── discovery_service.dart   # mDNS multicast_dns
│   ├── mjpeg_service.dart       # MJPEG stream decoder
│   ├── fcm_service.dart         # Firebase init + token lifecycle
│   └── settings_service.dart    # shared_preferences wrapper
├── providers/
│   ├── server_provider.dart     # ChangeNotifier: connection, status, video
│   ├── alarms_provider.dart     # ChangeNotifier: alarm list
│   └── config_provider.dart     # ChangeNotifier: config params
├── pages/
│   ├── discovery_page.dart      # Splash: auto-discover or manual IP
│   ├── dashboard_page.dart      # Video MJPEG + status cards + armario
│   ├── alarms_page.dart         # Alarm list with colors
│   ├── config_page.dart         # Sliders by category
│   └── settings_page.dart       # App + notification prefs
└── widgets/
    ├── mjpeg_viewer.dart        # Image.memory() fed from MJPEG stream
    └── status_card.dart         # Card with label + value + color
```

### Key implementation details

#### discovery_service.dart
```dart
class DiscoveryService {
  final MDnsClient _client = MDnsClient();
  Stream<PtrResourceRecord> discover() {
    return _client
        .lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer('_cocinap._tcp.local.'),
        );
  }
}
```

#### mjpeg_viewer.dart
```dart
class MjpegViewer extends StatefulWidget {
  final String url;
  // Opens HTTP connection to /api/stream
  // Reads multipart boundary, extracts JPEG frames
  // Calls widget.onFrame(Uint8List) for each frame
  // Uses Image.memory(bytes) to display
}
```

#### FCM registration flow
1. App starts → `firebase_messaging` gets token
2. App POSTs token to `CocinaP/api/register_token`
3. When alarm fires, Windows sends FCM via firebase-admin
4. App receives in `onMessage` (foreground) or background handler
5. `flutter_local_notifications` displays the notification

#### Server auto-discovery flow
1. App starts → DiscoveryPage shown
2. `multicast_dns` scans for `_cocinap._tcp.local.`
3. If found: auto-connect, navigate to Dashboard
4. If not found after 5s: show manual IP input
5. IP saved to shared_preferences for future auto-connect

## Implementation order

1. Backend: config.py + runner.py (15 min)
2. Backend: webui.py MJPEG + SSE + mDNS + FCM (2-3 hours)
3. Backend: engine.py wiring (15 min)
4. Backend: requirements.txt update (5 min)
5. Backend: test MJPEG in browser (15 min)
6. Flutter: `flutter create` + pubspec.yaml (15 min)
7. Flutter: Services (api, discovery, mjpeg, fcm, settings) (1-2 hours)
8. Flutter: Providers (server, alarms, config) (1 hour)
9. Flutter: Pages (discovery, dashboard, alarms, config, settings) (2-3 hours)
10. Flutter: Widgets (mjpeg_viewer, status_card) (30 min)
11. Integration test: PC + phone on same LAN (1 hour)

## Firebase setup required

1. Create project at https://console.firebase.google.com
2. Enable Cloud Messaging (FCM)
3. Download service account key → save to `%APPDATA%/CocinaP/firebase-key.json`
4. In config, set `ENABLE_FCM = True`
5. For Flutter: `flutterfire configure` → generates `firebase_options.dart`
