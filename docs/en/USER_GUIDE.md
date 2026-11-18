# User guide — CocinaP

Guide to using the **CocinaP** mobile app and the full system.

---

## 1. What CocinaP does

CocinaP watches your kitchen and alerts you if it becomes **unattended**. It
uses your phone camera or an IP camera and detects people directly on the
device.

- **Local mode:** the phone uses its own camera or an IP camera on the local
  network. The existing local workflow does not require a PC.
- **Remote desktop video (optional):** the phone can receive the CocinaP
  Desktop camera stream over a private Tailscale network. The app does not
  currently receive desktop alarms or run reliably in the background.

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
- **Remote Windows camera (optional):** receives video from CocinaP running on
  a Windows PC. Tailscale must be installed on both the PC and phone and joined
  to the same private tailnet; see the steps below. Local camera modes remain
  available without Tailscale.

The sheet includes a short **tutorial** on the available sources.

### 4.2 Configure optional remote access

1. Keep a Windows PC powered on at home and install Tailscale on both the PC
   and phone. Sign in to the same account/private tailnet on both.
2. Open CocinaP on Windows, select the camera, and enable **Allow remote
   access** in Settings. Keep the app open and monitoring active.
3. Run `tailscale serve --bg 8080` in PowerShell. Use `tailscale serve status` to
   find the private HTTPS address ending in `.ts.net`.
4. Connect Tailscale on the phone. In CocinaP mobile Settings, choose the
   remote PC camera source, enter the HTTPS address and API key shown in
   Windows Settings, and test the connection.

Do not configure router port forwarding or use Tailscale Funnel. The PC must
remain powered on, awake, connected to Tailscale and connected to the camera.
Windows webcam snapshots are sent at about one frame per second. Phone-side
detection works only while the mobile app is open; desktop alerts are not
synchronized to the phone. Disable remote access with `tailscale serve reset`
when it is no longer needed.

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

For viewing the PC camera when the phone is away from home, both devices must
be connected to the same private Tailscale network:

1. Install Tailscale on the Windows PC and phone and sign in to the same
   private network.
2. Open CocinaP on Windows, select the camera, and enable **Allow remote
   access** in Settings. Keep the app open and monitoring active.
3. On the PC, run `tailscale serve --bg 8080` in PowerShell. Use
   `tailscale serve status` to find the private HTTPS address ending in
   `.ts.net`.
4. Copy the API key shown in Windows Settings. In mobile **Settings**, choose
   the remote PC camera source, enter the HTTPS address and key, and test the
   connection.

Do not expose port 8080 through router port forwarding or use Tailscale Funnel.
The phone can show the stream and run its person detector while the app is
open. The Windows PC must stay awake with CocinaP running. Webcam snapshots
are sent at about one frame per second. Desktop alerts are not synchronized to
the phone.

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
local IP camera. Remote desktop video is sent over your private Tailscale
network. See the [Privacy policy](../legal/PRIVACY_POLICY.en.md).

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
