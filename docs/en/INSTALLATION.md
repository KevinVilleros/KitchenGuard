# Installation & build — CocinaP

Complete guide to prepare the environment, build and install the mobile app and
the PC backend.

---

## 1. System requirements

### To develop the mobile app

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | 3.32+ (tested on 3.47) | Includes Dart 3.2+ |
| Dart | 3.2+ | Bundled with Flutter |
| Android SDK | API 26+ | With `platform-tools` (adb) |
| Java JDK | 17 or 21 | For Gradle/Android |
| Xcode | 16+ | macOS only, for local iOS |
| Git | 2.x | Version control |

### To run the PC backend

| Tool | Version | Notes |
|---|---|---|
| Python | 3.10+ | With `pip` |
| Windows | 10 or 11 | For the PySide6 GUI |

### Devices

- **Android:** 8.0+ (API 26+), with USB debugging enabled.
- **iOS:** 17.0+.
- **Network:** WiFi on the same subnet as the PC (connected mode only).

---

## 2. Development environment

### 2.1 Windows (PowerShell)

```powershell
# Flutter and JDK paths (example)
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
$env:Path = "C:\flutter\bin;$env:JAVA_HOME\bin;$env:Path"

# Verify
flutter --version
flutter doctor
```

> On Windows PowerShell 5.1 do not use `&&`; chain with `;` or `if ($?) { ... }`.

### 2.2 Flutter verification

```bash
flutter doctor -v
```

Resolve anything `doctor` flags (Android licenses, devices, etc.) before
building.

---

## 3. Mobile app — build & install

### 3.1 Get dependencies

```bash
cd cocinap_mobile
flutter pub get
```

### 3.2 Run in development mode

```bash
flutter devices          # list connected devices
flutter run              # build and run on the selected device
```

### 3.3 Android — APK

```bash
cd cocinap_mobile
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Install over USB:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Other variants:

```bash
flutter build appbundle --release   # AAB for Google Play
flutter build apk --debug           # Debug APK
```

### 3.4 iOS — build without a Mac (GitHub Actions)

Building iOS requires macOS with Xcode. Without a Mac, the project produces the
`.ipa` **in the cloud** via GitHub Actions:

1. Push to `main` (or run the workflow manually in
   `Actions → iOS Build CocinaP → Run workflow`).
2. When it finishes, download the **`CocinaP-iOS`** artifact (unsigned `.ipa`).
3. Install it on the iPhone with **Sideloadly**.

Detailed steps and images: [INSTALL_IOS_WINDOWS.es.md](../INSTALL_IOS_WINDOWS.es.md).

> Note: an `.ipa` signed with Sideloadly (free account) **expires after 7 days**
> and must be reinstalled. A paid developer certificate avoids that expiry.

### 3.5 iOS — build on macOS

```bash
cd cocinap_mobile
flutter build ipa --release --export-method ad-hoc
# Output: build/ios/ipa/*.ipa
```

---

## 4. PC backend — install & run

> The backend is archived under `yolo/`. It is optional and only adds
> fire/smoke detection and the server for connected mode.

### 4.1 Create a virtual environment and install dependencies

```powershell
cd yolo
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 4.2 Run

```powershell
python main.py
```

The desktop GUI opens with the **Camera**, **Config** and **Alarms** tabs. On
startup, the HTTP server listens on port **8080** and shows the local IPs and the
**API key** (generated on first run).

### 4.3 Package an executable

```powershell
python build_app.py        # builds the .exe with PyInstaller
python build_all.py        # full build (app + installer)
```

---

## 5. Connect the mobile app to the PC

1. Make sure the phone and PC are on the **same WiFi network**.
2. On the PC, open CocinaP and locate the **API key** (connection dialog or console).
3. In the mobile app, go to the **Connect** tab and pick a method:
   - **Search network** (mDNS): finds the PC automatically.
   - **Scan PC QR**: on the PC, press "Show QR code".
   - **Connect manually**: enter `http://IP:8080` and the API key.
4. Press connect. The status should become **Connected**.

See the [User guide](USER_GUIDE.md) for daily use.

---

## 6. Reference builds (CI)

The repository includes workflows in `.github/workflows/`:

| Workflow | Trigger | Result |
|---|---|---|
| `ios.yml` ("iOS Build CocinaP") | push to `main` touching `cocinap_mobile/**`, or manual | unsigned `.ipa` (artifact `CocinaP-iOS`) |
| `python-ci.yml` | changes under `yolo/**` | backend lint + tests |

See [Testing & CI/CD](TESTING.md).

---

## 7. Common installation issues

| Symptom | Likely cause | Fix |
|---|---|---|
| `flutter doctor` flags Android | Licenses not accepted | `flutter doctor --android-licenses` |
| Gradle fails on Java | Incompatible JDK | Use JDK 17/21 and export `JAVA_HOME` |
| `adb` can't find device | USB debugging off | Enable it and accept the prompt |
| iOS build fails | Missing signing | Use the unsigned `.ipa` with Sideloadly |
| `pip install` fails | No compilers | Install Visual Studio Build Tools |

More cases in [Troubleshooting](TROUBLESHOOTING.md).
