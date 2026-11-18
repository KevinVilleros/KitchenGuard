# Installation & build — CocinaP

Complete guide to prepare, build and install CocinaP on Android, iOS and
Windows.

---

## 1. System requirements

### Flutter development

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | 3.32+ (tested on 3.47) | Includes Dart 3.2+ |
| Dart | 3.2+ | Bundled with Flutter |
| Android SDK | API 26+ | With `platform-tools` (adb) |
| Java JDK | 17 or 21 | For Gradle/Android |
| Xcode | 16+ | macOS only, for local iOS |
| Visual Studio | 2022 | Windows: **Desktop development with C++** workload |
| Windows Developer Mode | Enabled | Required for plugin symlinks in desktop builds |
| Git | 2.x | Version control |

### Devices

- **Android:** 8.0+ (API 26+), with USB debugging enabled.
- **iOS:** 17.0+.
- **Windows:** 10 or 11.
- **Network:** same LAN as the IP camera for local discovery; Tailscale on the
  phone and Windows PC for remote video.

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

## 4. Windows desktop app — build & run

The Windows app is the same Flutter application as the mobile app. It uses
MoveNet Lightning through ONNX Runtime for local person detection.

### 4.1 Requirements

- Windows 10 or 11.
- Flutter stable with Windows desktop support enabled.
- Visual Studio 2022 with the **Desktop development with C++** workload and
  its default components.
- Windows Developer Mode enabled so Flutter can create plugin symlinks.

Check the setup with `flutter doctor -v`.

### 4.2 Run or build

```powershell
cd cocinap_mobile
flutter pub get
flutter run -d windows
# Or create a release build:
flutter build windows --release
```

The executable and its required runtime files are placed under
`cocinap_mobile/build/windows/runner/Release/`. The webcam snapshot path is
limited to about one frame per second; Windows person detection uses a single
MoveNet pose and is not identical to mobile ML Kit.

---

## 5. Optional remote desktop video

The mobile app's remote desktop source uses a private Tailscale network; it
does not use the legacy mDNS/QR server-connection workflow.

1. Install Tailscale on the Windows PC and phone and sign in to the same
   private network.
2. Open CocinaP on Windows, select the desired camera, and enable **Allow
   remote access** in Settings. Keep the app open and monitoring active.
3. In PowerShell on the PC, run `tailscale serve --bg 8080`. Use
   `tailscale serve status` to find the HTTPS address ending in `.ts.net`.
4. Copy the API key shown in Windows Settings. In mobile **Settings**, choose
   the remote PC camera source, enter the HTTPS address and key, and test the
   connection.

Do not expose port 8080 through router port forwarding or use Tailscale Funnel.
The Windows PC must stay awake, connected to Tailscale, and running CocinaP.
The phone runs its own person detector while the app is open; desktop alarms
are not synchronized to the phone.

See the [User guide](USER_GUIDE.md) for daily use.

---

## 6. Reference builds (CI)

The repository includes workflows in `.github/workflows/`:

| Workflow | Trigger | Result |
|---|---|---|
| `ios.yml` ("iOS Build CocinaP") | push to `main` touching `cocinap_mobile/**`, or manual | unsigned `.ipa` (artifact `CocinaP-iOS`) |

See [Testing & CI/CD](TESTING.md).

---

## 7. Common installation issues

| Symptom | Likely cause | Fix |
|---|---|---|
| `flutter doctor` flags Android | Licenses not accepted | `flutter doctor --android-licenses` |
| Gradle fails on Java | Incompatible JDK | Use JDK 17/21 and export `JAVA_HOME` |
| `adb` can't find device | USB debugging off | Enable it and accept the prompt |
| iOS build fails | Missing signing | Use the unsigned `.ipa` with Sideloadly |
| Windows build reports missing symlink support | Developer Mode is off | Enable Windows Developer Mode and rerun `flutter pub get` |
| Windows build cannot find C++ tools | Visual Studio workload missing | Install Visual Studio 2022 with **Desktop development with C++** |

More cases in [Troubleshooting](TROUBLESHOOTING.md).
