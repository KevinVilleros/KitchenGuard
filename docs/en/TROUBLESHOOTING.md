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

- Confirm the phone and camera are on the same Wi-Fi/LAN and the router shows
  the camera connected.
- Automatic search finds cameras that advertise **ONVIF**; enable ONVIF in the
  camera settings if the manufacturer provides that option.
- If it is not found, the camera may not support ONVIF or the router may isolate
  Wi-Fi clients. Use manual setup only if you have the full **RTSP** or
  **HTTP/MJPEG** stream URL; the IP address alone does not identify a stream.
- If it is found but ONVIF setup fails, tap the pencil next to the camera to
  reuse its IP and edit example RTSP paths. Check the exact path and RTSP
  credentials in the camera app, web settings or manual; suggested paths may
  not match the model.
- V380 Pro is an app name and does not guarantee all associated models expose
  ONVIF/RTSP. Model **AIT36106** has not been validated with CocinaP.
- On iPhone, this build cannot use ONVIF multicast discovery because it requires
  an Apple entitlement that is not included. Return to manual setup and use a
  compatible stream URL.

### Cannot connect to CocinaP Windows away from home

- Confirm Tailscale is connected on both the phone and PC and both belong to
  the same private tailnet.
- On the PC, confirm CocinaP is running, remote access is enabled in Settings,
  and check `tailscale serve
  status`. Enter the complete HTTPS address ending in `.ts.net`; the app
  rejects HTTP and public addresses.
- Copy the API key again from Windows Settings. The app sends it in an HTTPS
  header; do not put it in the URL.
- Do not forward router port 8080 or use Tailscale Funnel.
- Keep the Windows PC awake with monitoring active. Desktop alerts are not
  synchronized to the phone.

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

## 4. Windows app

### Windows build requests Developer Mode

Enable Windows Developer Mode, then rerun `flutter pub get`.

### Windows build cannot find C++ tools

Install Visual Studio 2022 with the **Desktop development with C++** workload.

### MoveNet model fails to load

Confirm the app bundle includes `assets/models/movenet_lightning.onnx` and
rebuild after changing dependencies. See the error in the Flutter debug log.

### No camera signal on Windows

- Check Windows **Settings > Privacy & security > Camera** permissions.
- Close other applications using the webcam and select the camera source again.
- Webcam capture is snapshot-based (about 1 FPS); use an IP camera for a
  continuous higher-rate stream.

### Remote stream unavailable

- Keep CocinaP running on the PC and verify its camera is active.
- Confirm Tailscale is connected on both devices and `tailscale serve status`
  shows the expected `.ts.net` address.
- Verify the API key and do not expose port 8080 through the router.

---

## 5. FAQ

**Do I need the PC to use the app?**
No. Standalone mode works with the phone alone (person detection).

**Does it detect fire and smoke without a PC?**
No. CocinaP currently detects people only.

**Are my videos uploaded to the Internet?**
No. All processing is local (device or your PC).

**Why does the IPA expire?**
Sideloadly with a free account signs for 7 days. A paid certificate avoids the
expiry.

**Does it work in the background?**
Android uses a foreground service and can reconnect the video when you return
to the app. iOS suspends the camera connection in the background: keep the app
open and return to it to reconnect the stream.

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
