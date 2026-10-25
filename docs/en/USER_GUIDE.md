# User guide — CocinaP

Guide to using the **CocinaP** mobile app and the full system.

---

## 1. What CocinaP does

CocinaP watches your kitchen and alerts you if it becomes **unattended**. It
uses your phone camera or an IP camera and detects people directly on the
device.

- **Standalone mode:** phone only. No PC or Internet required.
- **Connected mode:** if you have the PC running CocinaP, the app connects over
  WiFi and adds the PC camera and **fire and smoke** alarms.

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
- **IP camera:** enter the stream URL (e.g. `http://192.168.1.50:8080/video` or
  an MJPEG URL).
- **PC with CocinaP:** if connected, opens the PC camera; otherwise it takes you
  to **Connect**.

The sheet includes a short **tutorial** on the three ways to connect a camera.

### 4.2 Start monitoring

1. Choose the **monitoring window** duration (e.g. 15, 30 or 60 min).
2. Press **Start**. The countdown begins.
3. The app watches for people in frame:
   - **Person detected:** the kitchen is attended.
   - **No person:** after the configured time, a **local alert** fires (sound and
     vibration) plus a notification.
4. You can **Pause**, **Resume** or **Stop** at any time.

### 4.3 Monitoring settings

In **Settings** you can configure:

| Setting | Description |
|---|---|
| Monitoring duration | Window in minutes |
| Seconds without a person to alert | Absence threshold |
| Danger minutes | Time considered dangerous while unattended |
| Detection confidence | Detector sensitivity (0.2–0.9) |
| Camera source | Phone or IP |

---

## 5. Connecting to the PC (connected mode)

If you have the PC running CocinaP on the same WiFi network:

1. Go to the **Connect** tab.
2. Pick a method:

   | Method | How |
   |---|---|
   | **Search network** | Press search; finds the PC via mDNS |
   | **Scan QR** | On the PC press "Show QR code" and scan it |
   | **Manual** | Enter `http://IP:8080` and the API key |

3. When the status is **Connected**, the **Alarms** tab and the PC camera become
   available.

The app remembers the last server and can reconnect automatically.

---

## 6. Alarms

The **Alarms** tab shows the real-time history (received via SSE from the PC).
Each alarm includes:

- **Time**
- **Severity:** CRITICAL, HIGH, MEDIUM, LOW
- **Message** and **type** (fire, smoke, unattended cooking)

Besides PC alarms, in standalone mode the app generates **local alerts** for
unattended cooking with sound and vibration.

---

## 7. Settings

| Section | Options |
|---|---|
| Connection | Server, API key, auto-connect, recent servers |
| Monitoring | Duration, thresholds, confidence |
| Camera | Source (phone/IP), URL |
| Interface | Language (ES/EN), replay tour |
| Guides | Manual, camera guide, terms |
| About | Version and credits |

---

## 8. Usage tips

- **Camera placement:** cover the whole cooking area, with good light and no
  obstacles.
- **IP camera:** use an MJPEG URL reachable from the local network; avoid
  cameras that only expose RTSP (the phone uses MJPEG).
- **Battery:** camera monitoring drains battery; keep the phone charging for long
  sessions.
- **Fire and smoke:** require the PC to be connected (the phone alone detects
  people only).

---

## 9. Privacy

Images are processed **on the device** or on your own PC; they are not sent to
external servers. See the [Privacy policy](../legal/PRIVACY_POLICY.en.md).

---

## 10. Extras

- **Language:** Spanish by default; switch to English in Settings.
- **Notifications:** Android allows background alerts; iOS only while the app is
  open.
- **Reconnect:** on startup the app tries the last server and, if it fails,
  searches the network.
