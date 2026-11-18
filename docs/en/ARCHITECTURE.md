# Architecture — CocinaP

Reference document for the CocinaP system architecture. It describes the
components, how they communicate, the data flow and the structural decisions.

---

## 1. Overview

CocinaP is one Flutter application for **Android, iOS and Windows**. It supports
local monitoring with an on-device camera or IP camera and optionally lets a
phone view the Windows camera after QR pairing through CocinaP Cloud. Detection
runs locally: ML Kit Pose Detection on Android/iOS and MoveNet Lightning
through ONNX Runtime on Windows.

```
                         ┌───────────────────────────────────────────┐
                         │            MOBILE APP (Flutter)            │
                         │  Android / iOS / Windows                   │
                         │                                            │
   Phone camera ───────► │  Standalone mode                           │
   (or IP camera)           │   • ML Kit / MoveNet: person detection      │
                         │   • Monitoring timer                       │
                         │   • Local alarms (sound/vibration)         │
                         │                                            │
                         │  Remote cloud video (optional)              │
                         │   • QR and tokens via Cloudflare Worker     │
                         │   • Live video through LiveKit              │
                         └───────────────┬────────────────────────────┘
                                         │  LiveKit (stream + status)
                                         │  HTTPS (tokens)
                                         ▼
                  ┌─────────────────────────────────────┐
                  │   CocinaP (Flutter, Windows)        │
                  │ Local camera + MoveNet              │
                  │ Local MJPEG → FFmpeg/OpenH264       │
                  └──────────────────┬──────────────────┘
                                     │ RTMPS
                                     ▼
                               LiveKit Cloud
                                     ▲
                                     │ HTTPS: phone token
                           Cloudflare Worker
                                     ▲
                                     │ HTTPS: QR/credentials
                                Mobile app
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
| Services | `lib/services/` | HTTP, ONVIF, MJPEG, detection, notifications and settings |
| Content | `lib/content/` | Bilingual ES/EN strings |

**Providers:**

| Provider | Responsibility |
|---|---|
| `StandaloneProvider` | Local or remote camera source, timer, person detection and alerts |
| `TourController` | Guided UI tour state |

**Services:**

| Service | Responsibility |
|---|---|
| `RemoteDesktopService` | Validates Tailscale Serve URL and tests the desktop API |
| `RemoteCloudService` | Registers the device and requests cloud tokens |
| `RemoteCloudHostService` | Starts the local MJPEG server and LiveKit publishers |
| `MjpegService` | Receives the selected camera's MJPEG stream |
| `PersonDetector` | ML Kit on Android/iOS; delegates to MoveNet on Windows |
| `WindowsPersonDetector` | MoveNet Lightning inference via ONNX Runtime |
| `RemoteCameraServer` | Authenticated Windows MJPEG host on port 8080 |
| `BackgroundServiceManager` | Background service and local notifications |
| `SettingsService` | Persistence with `SharedPreferences` |

### 2.2 Windows desktop target

The Windows runner is part of `cocinap_mobile/windows/` and shares the Flutter
UI, provider state, camera sources, monitoring timer and alerts. Webcam
snapshots are captured about once per second because `camera_windows` does not
provide an image stream. MoveNet Lightning detects one person per frame; this
is a different model and output shape from mobile ML Kit.

When cloud access is enabled, `RemoteCameraServer` serves local MJPEG to FFmpeg,
which publishes it to LiveKit over RTMPS; another publisher sends monitoring
state. The phone requests a token from the Cloudflare gateway and connects to
LiveKit to receive video. The PC must remain on, connected to the internet, and
running CocinaP. Tailscale remains available as a separate advanced option.

---

## 3. Data flow

### 3.1 Standalone mode (on-device)

```
CameraController ──frame──► PersonDetector (ML Kit / MoveNet)
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
2. `PersonDetector` runs platform-specific pose detection locally and returns
   person boxes and confidence scores.
3. `StandaloneProvider` sets `personPresent` and resets the absence counter when
   someone is present.
4. If the timer is running and the threshold elapses with no people, a local
   alert is fired.

### 3.2 Remote cloud video (optional)

```
Mobile app          Cloudflare Worker        LiveKit          CocinaP Windows
   │                     │                     │                     │
   │── credentials ─────►│                     │                     │
   │◄── token ───────────│                     │                     │
   │──────────────────── connect ─────────────►│                     │
   │◄════════ video + status ═════════════════│◄──── RTMPS ─────────│
```

- The PC registers once and uses an owner key to request publishing; the QR
  carries a separate read-only viewer key.
- The gateway issues short-lived tokens. Video travels through LiveKit; this
  should not be described as entirely local processing.
- The phone and PC need internet access. The QR is a credential and must not
  be published. The test version has no billing, in-app revocation, or
  reliable push notifications.

---

## 4. AI models

| Context | Model | Input | Outputs | Where |
|---|---|---|---|---|
| Android/iOS | ML Kit Pose Detection | Camera frame | Person poses | On-device |
| Windows | MoveNet Lightning (`movenet_lightning.onnx`) | `1x192x192x4` uint8 | One 17-keypoint pose | On-device (ONNX Runtime) |

Detection is local. When cloud remote access is enabled, live video is sent
through LiveKit; CocinaP has no video-recording feature. Windows webcam
snapshots limit its camera stream to approximately one frame per second.

---

## 5. Persistence

### Mobile app (`SharedPreferences`)

| Key | Use |
|---|---|
| `server_url` | Remote Windows HTTPS address |
| `standalone_*` | Duration, thresholds, confidence, camera source and URL |
| `desktop_host_api_key` | Windows host key in platform secure storage |
| `desktop_remote_host_enabled` | Whether the Windows MJPEG host starts |
| `cloud_gateway_url`, `cloud_device_id` | Gateway address and device identifier |
| `cloud_owner_key`, `cloud_viewer_key` | Cloud keys in secure storage |
| `cloud_host_enabled` | Whether the camera is published to the cloud |
| `has_seen_install_guide`, `has_seen_app_tour` | First-run flags |
| `app_language` | UI language (es/en) |

The Windows host key is stored using platform secure storage; it is only shown
in Settings so the user can configure the phone.

---

## 6. Network communication

- **Windows host:** HTTP on port 8080, bound to loopback by the Flutter app.
- **Cloud access:** host and phone tokens are issued by the gateway; video and
  monitoring state travel through LiveKit.
- **Advanced Tailscale:** the local MJPEG host uses port 8080; never expose it
  through router forwarding or Funnel.
- **Local endpoints:** `GET /api/info` and `GET /api/stream`.
- **MJPEG rate:** follows the selected camera; Windows webcam snapshots are
  captured at about one frame per second.

> Security: do not share the QR or expose port 8080 to the Internet. See
> [SECURITY](SECURITY.md).

---

## 7. Platform constraints

| Platform | Background notifications | Notes |
|---|---|---|
| Android | Depends on active service | No guaranteed remote push |
| iOS | Only while the app is open | System limitations for background work |
| Windows | While the app is running | The PC must remain awake; webcam snapshots are about 1 FPS |

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
                        │ LiveKit / HTTPS    │
                        └──────────┬─────────┘
                                   │ RTMPS
                          ┌────────▼─────────┐
                          │   Windows PC     │
                          │ CocinaP + FFmpeg │
                          │ MoveNet + MJPEG  │
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
├── cocinap_mobile/     # Flutter app for Android, iOS and Windows
├── docs/               # Documentation (es/ and en/)
├── .github/workflows/  # CI: mobile builds and CodeQL
├── CHANGELOG.md
└── LICENSE
```

See the [Development guide](DEVELOPMENT.md) for a per-file breakdown.
