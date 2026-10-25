# Development guide — CocinaP

Conventions, structure and workflow for developing CocinaP.

---

## 1. Set up the environment

### Mobile app (Flutter)

```powershell
# Windows PowerShell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
$env:Path = "C:\flutter\bin;$env:JAVA_HOME\bin;$env:Path"

cd cocinap_mobile
flutter pub get
flutter analyze
flutter run
```

### Backend (Python)

```powershell
cd yolo
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python main.py
```

---

## 2. Repository structure

```
KitchenGuard/
├── cocinap_mobile/            # Flutter app (main technology)
│   ├── lib/
│   │   ├── main.dart          # Startup, theme, navigation, tour
│   │   ├── content/           # Bilingual ES/EN strings
│   │   ├── pages/             # Screens
│   │   ├── providers/         # State (ChangeNotifier)
│   │   ├── services/          # HTTP, mDNS, MJPEG, TFLite, prefs
│   │   └── widgets/           # Reusable components
│   ├── android/  ios/         # Platform configuration
│   ├── assets/models/         # TFLite model
│   └── test/                  # Widget tests
├── yolo/                      # Python/YOLO backend (archived)
│   ├── cocinap/               # Python package
│   ├── tests/                 # pytest tests
│   └── docs/                  # Backend docs
├── docs/                      # General docs (es/ and en/)
├── .github/workflows/         # CI: ios.yml, python-ci.yml
├── .editorconfig              # Code style
├── CHANGELOG.md
└── LICENSE
```

### Mobile app detail

| File/folder | Role |
|---|---|
| `main.dart` | `MultiProvider`, `MaterialApp`, `MainShell` with 5 tabs, tour overlay |
| `content/content.dart` | Bilingual text classes (`NavLabels`, `HomeTexts`, `AppTour`, ...) |
| `pages/home_page.dart` | Graphic Home dashboard |
| `pages/onboarding_page.dart` | First-run onboarding |
| `pages/standalone_page.dart` | Monitoring; device/camera selector |
| `pages/discovery_page.dart` | Connection (QR/mDNS/manual) |
| `pages/dashboard_page.dart` | Live PC camera |
| `pages/alarms_page.dart` | Alarm history |
| `pages/ip_camera_page.dart` | Phone/IP camera source |
| `pages/help_page.dart` | Manual, guide and terms |
| `pages/settings_page.dart` | Preferences |
| `providers/server_provider.dart` | Connection state + mDNS |
| `providers/standalone_provider.dart` | Standalone monitoring |
| `providers/alarms_provider.dart` | SSE alarms |
| `providers/tour_controller.dart` | UI tour |
| `services/api_service.dart` | REST HTTP client |
| `services/discovery_service.dart` | mDNS discovery |
| `services/mjpeg_service.dart` | MJPEG parser |
| `services/person_detector.dart` | TFLite inference |
| `services/background_service.dart` | Background service |
| `services/settings_service.dart` | Persistence |
| `widgets/graphical.dart` | Rings, cards and timeline |
| `widgets/tour_overlay.dart` | Coach marks |
| `widgets/mjpeg_viewer.dart` | MJPEG player |
| `widgets/status_card.dart` | Status card |

---

## 3. Code conventions

### Dart / Flutter

- Follow `flutter_lints` (`analysis_options.yaml`).
- **State:** one `ChangeNotifier` per domain; expose clear getters and methods.
- **Widgets:** prefer `StatelessWidget`; use `StatefulWidget` only when needed.
- **Naming:** `snake_case` files, `PascalCase` classes.
- **UI language:** use `content.dart` for all strings (no literals).
- **No emojis** in the UI or code.
- Before committing: `flutter analyze` must be clean.

### Python

- Follow `ruff` (config in `pyproject.toml`).
- PEP 8 style, 4-space indentation.
- No emojis.
- `ruff check yolo/` and `ruff format yolo/`.

### Cross-cutting (`.editorconfig`)

- UTF-8 encoding, LF end-of-line (CRLF in `.bat`).
- No trailing whitespace (except Markdown).

---

## 4. Git workflow

1. Create a descriptive branch:
   ```bash
   git checkout -b feature/my-change
   ```
2. Concise, imperative commit messages. Conventional Commit prefixes are
   welcome (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`).
3. Before committing: lint, analyze and tests.
4. Open a Pull Request describing the change and the reason.

> Do not commit/push or open PRs unless explicitly requested.

---

## 5. Useful commands

### Flutter

```bash
flutter pub get            # dependencies
flutter analyze            # static analysis
flutter test               # tests
flutter run                # run on device
flutter build apk --release
flutter build ipa --release
flutter devices            # connected devices
dart format .              # formatting
```

### Python (backend)

```bash
python main.py             # run the desktop app
ruff check yolo/           # lint
ruff format yolo/          # format
pytest yolo/tests          # tests
python build_app.py        # package .exe
```

---

## 6. Adding a feature

Example: adding a new indicator to the Home panel.

1. Add the ES/EN strings in `content/content.dart`.
2. Create or reuse the widget in `lib/widgets/` (e.g. `graphical.dart`).
3. Consume the data from the relevant provider.
4. Add the widget to `home_page.dart`.
5. `flutter analyze` and `flutter test`.
6. Update the documentation and `CHANGELOG.md`.

---

## 7. Documentation style

- Every document has an `es/` and `en/` version.
- Markdown, no emojis.
- Diagrams in code blocks or Mermaid.
- Update this documentation when the software changes.

---

## 8. Platform notes

- **Android:** permissions in `AndroidManifest.xml` (INTERNET, CAMERA,
  FOREGROUND_SERVICE, POST_NOTIFICATIONS, WAKE_LOCK).
- **iOS:** deployment target 17.0; no Firebase so it can build without
  `google-services.json`.
- **Android/iOS:** on-device detection runs the same on both platforms.

See also [Testing & CI/CD](TESTING.md) and [Security](SECURITY.md).
