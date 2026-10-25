# Troubleshooting (FAQ) — CocinaP

Common errors and how to fix them, both in the mobile app and the backend.

---

## 1. Mobile app — build

### `flutter doctor` reports Android issues

```bash
flutter doctor --android-licenses
```

Accept the licenses and run `flutter doctor` again.

### Gradle error related to Java

Cause: incompatible JDK or missing `JAVA_HOME`.

```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Use **JDK 17 or 21**.

### `adb` doesn't detect the device

- Enable **USB debugging** on the phone.
- Accept the "Allow USB debugging?" prompt.
- Try another cable/port, or `adb kill-server` then `adb start-server`.

### APK won't install (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`)

Different signing between versions. Uninstall the previous one:

```bash
adb uninstall com.cocinap.mobile
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

---

## 2. Mobile app — runtime errors

### "No Material widget found"

Happens when an `InkWell`/button is used without a `Material` ancestor. This was
already fixed in the project by wrapping the tour in
`Material(type: MaterialType.transparency)`. If it reappears after a change,
wrap the new widget in `Material`.

### Red/yellow box with "RenderFlex overflowed"

A `Row`/`Column` overflows. Fixes applied in the project:

- `FittedBox` with padding on rings/cards.
- `maxLines` + `TextOverflow.ellipsis`.
- Avoid combining `Expanded`/`IntrinsicHeight` in timelines.

When adding UI, test on small screens (~411x921 logical px).

### IP camera shows no image

- Confirm the URL is **MJPEG** (e.g. `http://IP:port/video`).
- Cameras that only expose **RTSP** won't work directly on the phone.
- Verify the phone and camera are on the same network.
- Test the URL in a browser on the PC.

### Person detection doesn't alert

- Make sure the **timer** is started.
- Adjust **Confidence** (lower if it misses, higher if false positives).
- Review the **seconds without a person to alert** threshold.
- Verify the camera correctly covers the area.

### Background notifications don't arrive on iOS

System limitation: on iOS local notifications work **only while the app is
open**. Android supports background (foreground service).

---

## 3. PC connection

### The app can't find the PC (mDNS)

- Verify both are on the **same subnet**.
- Some routers block mDNS; use **QR** or **manual connection**.
- On the PC, check the server is running and shows the IPs.

### `401 unauthorized` when connecting

The **API key** doesn't match. Copy it from the PC (shown in the connection
dialog) and re-enter it in Settings.

### `429 rate_limited`

Too many rapid requests. Wait for `Retry-After` and retry.

### MJPEG stream keeps dropping

- May be WiFi instability.
- The server caps width at 480 px to save bandwidth.
- Reconnect; the app can auto-reconnect.

---

## 4. Backend (PC)

### `pip install` fails to build dependencies

Install **Visual Studio Build Tools** (needed by some packages like
numpy/opencv/PySide6).

### YOLO model won't load

- Check that `yolo/models/yolo11n.pt` exists.
- In packaged mode, the model is resolved via `sys._MEIPASS`.

### No camera signal on the PC

- Check the camera in **Config** (USB or RTSP/HTTP URL).
- Close other apps using the camera.
- Restart the app after changing the device/URL (requires a restart).

### Port 8080 is in use

Change it in `config.json` (`WEB_PORT`) or free the port.

---

## 5. FAQ

**Do I need the PC to use the app?**
No. Standalone mode works with the phone alone (person detection).

**Does it detect fire and smoke without a PC?**
No. Fire and smoke require the PC backend to be connected.

**Are my videos uploaded to the Internet?**
No. All processing is local (device or your PC).

**Why does the IPA expire?**
Sideloadly with a free account signs for 7 days. A paid certificate avoids the
expiry.

**Does it work in the background?**
Android yes (foreground service). iOS only while the app is open.

**Can I use multiple cameras?**
You can switch between the phone camera, an IP camera and the PC from
**Monitoring**.

---

## 6. Collecting diagnostic info

- **Mobile app:** screenshot of the error and reproduction steps.
- **Backend:** `%APPDATA%\CocinaP\logs\crash.log` and `eventos.log`.
- Version: in the app (**About**) and in the backend (`/api/info`).

When reporting, include version, platform and reproduction steps.

---

See also: [Installation](INSTALLATION.md), [User guide](USER_GUIDE.md).
