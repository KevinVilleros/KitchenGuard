# User guide — CocinaP

Guide to using the **CocinaP** mobile app and the full system.

---

## 1. What CocinaP does

CocinaP watches your kitchen and alerts you if it becomes **unattended**. It
uses your phone camera or an IP camera and detects people directly on the
device.

- **Local mode:** the phone uses its own camera or an IP camera on the local
  network. The existing local workflow does not require a PC.
- **Remote PC from anywhere (optional):** the PC publishes video through
  CocinaP Cloud and the phone pairs by scanning a QR code. Tailscale is not
  required. The PC must remain on and connected to the internet.

---

## 2. First run

The first time you open the app:

1. An **onboarding** runs with several pages: what CocinaP is, your goals, how it
   works and how to connect a camera.
2. A **camera installation and placement guide** is shown.
3. When you enter the app, a **guided tour** highlights each of the 5 tabs
   (Home, Monitoring, Connect, Alarms, Settings) with short explanations.

You can replay the tour anytime: **Settings → Interface tour**.
Change language: **Settings → Language** (Spanish / English).

---

## 3. The 5 tabs

| Tab | Purpose |
|---|---|
| **Home** | Graphic dashboard: status, goals, how it works and quick links |
| **Monitoring** | Watches the kitchen with the phone camera or an IP camera |
| **Connect** | Connects the app to the PC (QR, mDNS or manual) |
| **Alarms** | Real-time alarm history from the PC |
| **Settings** | Preferences, camera source, monitoring, language and help |

---

## 4. Monitoring (standalone mode)

The main feature without a PC.

### 4.1 Choose the camera source

In **Monitoring**, tap the **Devices** icon (top bar) or the
**"Change device or camera"** button. A sheet opens with the sources:

- **Phone camera:** uses the phone camera.
- **IP camera:** tap **Configure** to find ONVIF cameras on your Wi-Fi. The
  phone and camera must be on the same network with ONVIF enabled. Select the
  camera and enter its credentials. If it is not found, enter a full HTTP/MJPEG
  or RTSP URL from the camera manual or app; an IP address alone is not enough.
  iOS requires an Apple entitlement for automatic ONVIF multicast discovery,
  which is not included in this build. Credentials are stored securely on the
  device. ONVIF and RTSP may use different credentials; enter
  the RTSP credentials when prompted. If ONVIF setup fails, tap the pencil next
  to the discovered camera to edit a suggested URL using its IP. Suggested
  paths are examples and are not guaranteed to work. Find the exact RTSP URL in
  the camera app, web settings or manual; the router’s device list usually only
  provides the IP address.
- **Remote PC from anywhere (optional):** receives video from CocinaP on
  Windows through CocinaP Cloud. Pairing uses a QR code and does not require
  Tailscale; see the steps below.

The sheet includes a short **tutorial** on the available sources.

### 4.2 Pair a Windows PC from anywhere

1. On the PC, open CocinaP and confirm that the selected camera shows video.
2. In **Settings**, turn on **Access from anywhere**. CocinaP will start the
   cloud connection and display a QR code.
3. On the phone, open CocinaP and go to **Settings > Camera source > Remote PC
   over cloud**, then scan the PC's QR code.
4. Keep the PC on, CocinaP open, and the PC connected to the internet. The
   phone can receive video from another network without router changes or
   installing Tailscale.

The QR is private: it grants access to that camera's video and monitoring
status. Scan it only with trusted phones. Phone detection and alerts depend on
the app remaining open;
reliable background push notifications are not available in this version.
Cloud access is a test feature and does not yet manage or bill subscriptions.

### 4.3 Start monitoring

1. Choose the **monitoring window** duration (e.g. 15, 30 or 60 min).
2. Press **Start**. The countdown begins.
3. The app watches for people in frame:
   - **Person detected:** the kitchen is attended.
   - **No person:** after the configured time, a **local alert** fires (sound and
     vibration) plus a notification.
4. You can **Pause**, **Resume** or **Stop** at any time.

### 4.4 Monitoring settings

In **Settings** you can configure:

| Setting | Description |
|---|---|
| Monitoring duration | Window in minutes |
| Seconds without a person to alert | Absence threshold |
| Danger minutes | Time considered dangerous while unattended |
| Detection confidence | Detector sensitivity (0.2–0.9) |
| Camera source | Phone, local IP, or remote PC |

---

## 5. Remote desktop video (optional)

Turn on **Access from anywhere** in Windows Settings and pair the phone by
scanning the QR code, as described in Section 4.2. You do not need to open
router ports or install Tailscale. VPN/Tailscale remains available in advanced
settings for self-managed setups.

---

## 6. Alarms

The app generates local unattended-kitchen alerts with sound and vibration
while monitoring is active. Fire and smoke detection are not provided.

---

## 7. Settings

| Section | Options |
|---|---|
| Monitoring | Duration, thresholds, confidence |
| Camera | Source (phone, IP camera, or optional remote desktop video) |
| Interface | Language (ES/EN), replay tour |
| Guides | Manual, camera guide, terms |
| About | Version and credits |

---

## 8. Usage tips

- **Camera placement:** cover the whole cooking area, with good light and no
  obstacles.
- **IP camera:** ONVIF discovery searches the local network. If the camera is
  not found, check that ONVIF is enabled and both devices are on the same Wi-Fi;
  you can also enter its HTTP/MJPEG or RTSP URL manually.
- **Battery:** camera monitoring drains battery; keep the phone charging for long
  sessions.
- **Fire and smoke:** are not detected by CocinaP.

---

## 9. Privacy

In local mode, images are processed on the phone or requested directly from the
local IP camera. When access from anywhere is enabled, video passes through
CocinaP Cloud and LiveKit infrastructure. See the
[Privacy policy](../legal/PRIVACY_POLICY.en.md).

---

## 10. Extras

- **Language:** Spanish by default; switch to English in Settings.
- **Background monitoring:** Android uses a visible foreground service for
  phone-camera monitoring, with an ongoing notification. IP-camera monitoring
  requires CocinaP to stay open. On iPhone, camera capture and detection pause
  when the app leaves the foreground; continuous monitoring requires an
  external host and push notifications, which are not yet available. Validate
  Android background operation on a physical phone; battery-management settings
  may still restrict it.
- **Camera reconnect:** the IP stream retries automatically, and you can use
  the refresh button. Returning to the app reconnects video if iOS or Android
  paused it.
