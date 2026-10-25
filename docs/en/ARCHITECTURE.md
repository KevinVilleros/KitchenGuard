# Architecture — CocinaP

Reference document for the CocinaP system architecture. It describes the
components, how they communicate, the data flow and the structural decisions.

---

## 1. Overview

CocinaP is a **kitchen safety** system made of two parts:

1. **Mobile app (Flutter)** — the main technology. It runs **standalone** on
   Android and iOS: it uses the phone camera or an IP camera and detects people
   **on-device** (TensorFlow Lite), with no PC and no cloud required.
2. **Python/YOLO backend (optional)** — a Windows desktop application that adds
   **fire and smoke** detection with a YOLO model, plus an HTTP server the mobile
   app can connect to over WiFi.

The mobile app can operate:

- **Standalone mode:** all processing happens on the phone.
- **Connected mode:** the app connects over WiFi to the PC backend and consumes
  its video stream, status, alarms and configuration.

```
                         ┌───────────────────────────────────────────┐
                         │            MOBILE APP (Flutter)            │
                         │  Android / iOS                             │
                         │                                            │
   Phone camera ───────► │  Standalone mode                           │
   (or IP camera)        │   • TFLite: person detection               │
                         │   • Monitoring timer                       │
                         │   • Local alarms (sound/vibration)         │
                         │                                            │
                         │  Connected mode                            │
                         │   • mDNS discovery · QR · manual URL       │
                         │   • MJPEG stream from PC                   │
                         │   • SSE alarms                             │
                         └───────────────┬────────────────────────────┘
                                         │  HTTP/1.1 (WiFi LAN)
                                         │  X-API-Key
                                         ▼
                         ┌───────────────────────────────────────────┐
                         │          PC BACKEND (Python, Windows)      │
                         │  PySide6 GUI + ThreadingHTTPServer         │
                         │                                            │
   USB / IP camera ─────► │  YOLO11n (fire/smoke/people)               │
                         │  Risk analyzer · Alarms                    │
                         │  Web UI (REST + MJPEG + SSE)               │
                         │  Security: API key, rate limit, audit      │
                         └───────────────────────────────────────────┘
```

---

## 2. Components

### 2.1 Mobile app (`cocinap_mobile/`)

Layered architecture with the **Provider** pattern for state.

| Layer | Folder | Responsibility |
|---|---|---|
| Entry | `lib/main.dart` | Startup, theme, navigation (5 tabs), tour, onboarding |
| UI | `lib/pages/` | Screens (Home, Monitoring, Connect, Alarms, Settings) |
| UI | `lib/widgets/` | Reusable components (graphs, MJPEG, tour) |
| State | `lib/providers/` | One `ChangeNotifier` per domain |
| Services | `lib/services/` | HTTP, mDNS, MJPEG, TFLite, notifications, prefs |
| Content | `lib/content/` | Bilingual ES/EN strings |

**Providers:**

| Provider | Responsibility |
|---|---|
| `ServerProvider` | PC connection state, mDNS discovery, API key, recent servers |
| `AlarmsProvider` | Alarms received from the server (SSE) |
| `StandaloneProvider` | Standalone monitoring: camera, timer, person detection, alerts |
| `TourController` | Guided UI tour state |

**Services:**

| Service | Responsibility |
|---|---|
| `ApiService` | HTTP client for the backend REST API (status, info, timers) |
| `DiscoveryService` | mDNS discovery of `_cocinap._tcp.local.` |
| `MjpegService` | MJPEG stream parser from the PC |
| `PersonDetector` | On-device TFLite inference (SSD MobileNet V2 / COCO) |
| `BackgroundServiceManager` | Background service and local notifications |
| `SettingsService` | Persistence with `SharedPreferences` |

### 2.2 PC backend (`yolo/`)

| Module | Responsibility |
|---|---|
| `cocinap/app.py` | Desktop GUI (PySide6): camera, config, alarms |
| `cocinap/engine.py` | Engine: detection, analysis and timer coordination |
| `cocinap/detector/` | `detector.py` (YOLO) and `runner.py` (inference loop) |
| `cocinap/analyzer/risk_analyzer.py` | Risk and alarm computation (fire/smoke/unattended) |
| `cocinap/camera/handler.py` | USB or IP camera capture (RTSP/HTTP) |
| `cocinap/webui.py` | HTTP server: REST, MJPEG and SSE |
| `cocinap/alarm/sound_alarm.py` | Sound alarm |
| `cocinap/security/` | Authentication (`auth`), rate limiting, audit, crypto |
| `cocinap/config.py` | Persistent configuration and parameter metadata |

> The backend is **archived** under `yolo/` (see `yolo/README.md`); the mobile
> app is the active technology and does not depend on it in standalone mode.

---

## 3. Data flow

### 3.1 Standalone mode (on-device)

```
CameraController ──frame──► PersonDetector (TFLite, SSD MobileNet v2)
                                   │
                          n persons detected
                                   │
                                   ▼
                          StandaloneProvider
                     (personPresent, absenceSeconds)
                                   │
              timerRunning && no person > threshold
                                   ▼
                     Local alert (sound + vibration)
                        + local notification
```

1. The camera produces frames in YUV/RGB.
2. `PersonDetector` resizes to `300x300x3` (uint8), runs the model and gets up
   to 20 detections; it filters the "person" class.
3. `StandaloneProvider` sets `personPresent` and resets the absence counter when
   someone is present.
4. If the timer is running and the threshold elapses with no people, a local
   alert is fired.

### 3.2 Connected mode (client-server)

```
Mobile app                                 PC backend
   │                                            │
   │── GET /api/info  (X-API-Key) ─────────────►│  validates and returns version/IPs
   │◄───────────────────────────────────────────│
   │── GET /api/stream?api_key=… ──────────────►│  continuous MJPEG
   │◄══════════ JPEG frames ════════════════════│
   │── GET /api/events?api_key=… ──────────────►│  SSE alarms
   │◄══════════ data: {alarm} ══════════════════│
   │── GET /api/status ────────────────────────►│  detection and timer status
   │── POST /api/timer/start ──────────────────►│  timer control
```

- The connection is established via **mDNS** (automatic), **QR** (payload
  `url|api_key`) or **manual URL**.
- All requests carry the `X-API-Key` header. Streams (MJPEG/SSE) pass it as the
  `api_key` query param because raw sockets cannot easily set headers.

---

## 4. AI models

| Context | Model | Input | Outputs | Where |
|---|---|---|---|---|
| Mobile app | SSD MobileNet V2 (COCO) | `1x300x300x3` uint8 | Up to 20 detections | On-device (TFLite) |
| PC backend | YOLO11n (`yolo11n.pt`) | Resized image | fire, smoke, people | PC |

- On the phone only **people** are detected (for the unattended mode). Fire and
  smoke require the PC to be connected.
- On the backend, `DETECT_SCALE` and `YOLO_IMGSZ` control inference cost/speed;
  the model runs on CPU by default.

---

## 5. Persistence

### Mobile app (`SharedPreferences`)

| Key | Use |
|---|---|
| `server_url`, `recent_servers` | Last URL and recent servers |
| `api_key` | Backend API key |
| `auto_connect` | Auto-connect on startup |
| `standalone_*` | Duration, thresholds, confidence, camera source and URL |
| `has_seen_install_guide`, `has_seen_app_tour` | First-run flags |
| `app_language` | UI language (es/en) |

### PC backend

- `%APPDATA%\CocinaP\config.json` — parameters and `STOVE_ZONE`.
- `%APPDATA%\CocinaP\logs\` — `eventos.log` and `crash.log`.
- `%APPDATA%\CocinaP\firebase-key.json` — FCM key (optional).

---

## 6. Network communication

- **Transport:** HTTP/1.1 over WiFi on the local network (trusted LAN).
- **MJPEG:** `multipart/x-mixed-replace` at ~30 fps, JPEG quality 65, max width
  480 px on the server side.
- **SSE:** `text/event-stream` with heartbeats every 0.5 s.
- **mDNS:** service `_cocinap._tcp.local.` with `version` and `auth` properties.
- **Default port:** 8080 (`WEB_PORT`).

> Security: the server is designed for a **trusted LAN**. Do not expose it to
> the Internet. See [SECURITY](SECURITY.md).

---

## 7. Platform constraints

| Platform | Background notifications | Notes |
|---|---|---|
| Android | Yes (foreground service) | Requires notification and data permissions |
| iOS | Only while the app is open | System limitations for background work |

On-device detection and local notifications do not use Firebase (FCM was removed
from the mobile client so it can build without `google-services.json`).

---

## 8. Deployment diagram

```
                 ┌─────────────┐        ┌─────────────┐
                 │  Smartphone │        │  Smartphone │
                 │   Android   │        │     iOS     │
                 │  (Flutter)  │        │  (Flutter)  │
                 └──────┬──────┘        └──────┬──────┘
                        │  WiFi LAN (optional) │
                        └──────────┬───────────┘
                                   │ HTTP :8080
                          ┌────────▼─────────┐
                          │   Windows PC     │
                          │  CocinaP backend │
                          │  (Python/YOLO)   │
                          └────────┬─────────┘
                                   │ USB / RTSP / HTTP
                          ┌────────▼─────────┐
                          │  Camera          │
                          │  (USB or IP)     │
                          └──────────────────┘
```

---

## 9. Folder structure (summary)

```
KitchenGuard/
├── cocinap_mobile/     # Flutter app (main technology)
├── yolo/               # Archived Python/YOLO backend
├── docs/               # Documentation (es/ and en/)
├── .github/workflows/  # CI: iOS build + Python CI
├── CHANGELOG.md
└── LICENSE
```

See the [Development guide](DEVELOPMENT.md) for a per-file breakdown.
