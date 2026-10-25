# Guía de desarrollo — CocinaP

Convenciones, estructura y flujo de trabajo para desarrollar CocinaP.

---

## 1. Preparar el entorno

### App móvil (Flutter)

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

## 2. Estructura del repositorio

```
KitchenGuard/
├── cocinap_mobile/            # App Flutter (tecnología principal)
│   ├── lib/
│   │   ├── main.dart          # Arranque, tema, navegación, tour
│   │   ├── content/           # Textos bilingües ES/EN
│   │   ├── pages/             # Pantallas
│   │   ├── providers/         # Estado (ChangeNotifier)
│   │   ├── services/          # HTTP, mDNS, MJPEG, TFLite, prefs
│   │   └── widgets/           # Componentes reutilizables
│   ├── android/  ios/         # Configuración de plataforma
│   ├── assets/models/         # Modelo TFLite
│   └── test/                  # Pruebas de widgets
├── yolo/                      # Backend Python/YOLO (archivado)
│   ├── cocinap/               # Paquete Python
│   ├── tests/                 # Pruebas pytest
│   └── docs/                  # Docs del backend
├── docs/                      # Documentación general (es/ y en/)
├── .github/workflows/         # CI: ios.yml, python-ci.yml
├── .editorconfig              # Estilo de código
├── CHANGELOG.md
└── LICENSE
```

### Detalle de la app móvil

| Archivo/carpeta | Rol |
|---|---|
| `main.dart` | `MultiProvider`, `MaterialApp`, `MainShell` con 5 pestañas, overlay del tour |
| `content/content.dart` | Clases de texto bilingüe (`NavLabels`, `HomeTexts`, `AppTour`, ...) |
| `pages/home_page.dart` | Dashboard gráfico de Inicio |
| `pages/onboarding_page.dart` | Onboarding de primer uso |
| `pages/standalone_page.dart` | Monitoreo; selector de dispositivos/cámara |
| `pages/discovery_page.dart` | Conexión (QR/mDNS/manual) |
| `pages/dashboard_page.dart` | Cámara del PC en vivo |
| `pages/alarms_page.dart` | Historial de alarmas |
| `pages/ip_camera_page.dart` | Fuente de cámara del móvil/IP |
| `pages/help_page.dart` | Manual, guía y términos |
| `pages/settings_page.dart` | Preferencias |
| `providers/server_provider.dart` | Estado de conexión + mDNS |
| `providers/standalone_provider.dart` | Monitoreo independiente |
| `providers/alarms_provider.dart` | Alarmas SSE |
| `providers/tour_controller.dart` | Tour de interfaz |
| `services/api_service.dart` | Cliente HTTP REST |
| `services/discovery_service.dart` | Descubrimiento mDNS |
| `services/mjpeg_service.dart` | Parser MJPEG |
| `services/person_detector.dart` | Inferencia TFLite |
| `services/background_service.dart` | Servicio en segundo plano |
| `services/settings_service.dart` | Persistencia |
| `widgets/graphical.dart` | Anillos, tarjetas y timeline |
| `widgets/tour_overlay.dart` | Coach marks |
| `widgets/mjpeg_viewer.dart` | Reproductor MJPEG |
| `widgets/status_card.dart` | Tarjeta de estado |

---

## 3. Convenciones de código

### Dart / Flutter

- Sigue `flutter_lints` (`analysis_options.yaml`).
- **Estado:** un `ChangeNotifier` por dominio; expón getters y métodos claros.
- **Widgets:** prefiere `StatelessWidget`; usa `StatefulWidget` solo con estado.
- **Nombres:** archivos en `snake_case`, clases en `PascalCase`.
- **Idioma de la UI:** usa `content.dart` para todos los textos (sin literales).
- **Sin emojis** en la UI ni en el código.
- Antes de commit: `flutter analyze` debe quedar limpio.

### Python

- Sigue `ruff` (config en `pyproject.toml`).
- Estilo PEP 8, indentación de 4 espacios.
- Sin emojis.
- `ruff check yolo/` y `ruff format yolo/`.

### Transversal (`.editorconfig`)

- Codificación UTF-8, fin de línea LF (CRLF en `.bat`).
- Sin espacios en blanco al final (excepto Markdown).

---

## 4. Flujo de trabajo Git

1. Crea una rama descriptiva:
   ```bash
   git checkout -b feature/mi-cambio
   ```
2. Commits con mensajes concisos y en imperativo. Se aceptan prefijos tipo
   Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`).
3. Antes de commitear: lint, analyze y tests.
4. Abre un Pull Request describiendo el cambio y el motivo.

> No se hace `commit`/`push` ni se crean PRs sin que se indique explícitamente.

---

## 5. Comandos útiles

### Flutter

```bash
flutter pub get            # dependencias
flutter analyze            # análisis estático
flutter test               # pruebas
flutter run                # ejecutar en dispositivo
flutter build apk --release
flutter build ipa --release
flutter devices            # dispositivos conectados
dart format .              # formateo
```

### Python (backend)

```bash
python main.py             # ejecutar la app de escritorio
ruff check yolo/           # lint
ruff format yolo/          # formato
pytest yolo/tests          # pruebas
python build_app.py        # empaquetar .exe
```

---

## 6. Agregar una funcionalidad

Ejemplo: añadir un nuevo indicador al panel de Inicio.

1. Añade los textos ES/EN en `content/content.dart`.
2. Crea o reutiliza el widget en `lib/widgets/` (p. ej. `graphical.dart`).
3. Consume los datos desde el provider correspondiente.
4. Añade el widget a `home_page.dart`.
5. `flutter analyze` y `flutter test`.
6. Actualiza la documentación y el `CHANGELOG.md`.

---

## 7. Estilo de documentación

- Todo documento tiene versión `es/` y `en/`.
- Markdown, sin emojis.
- Diagramas en bloques de código o Mermaid.
- Actualiza esta documentación cuando cambie el software.

---

## 8. Notas de plataforma

- **Android:** permisos en `AndroidManifest.xml` (INTERNET, CAMERA,
  FOREGROUND_SERVICE, POST_NOTIFICATIONS, WAKE_LOCK).
- **iOS:** deployment target 17.0; sin Firebase para poder compilar sin
  `google-services.json`.
- **Android/iOS:** la detección on-device corre igual en ambas plataformas.

Ver también [Pruebas y CI/CD](TESTING.md) y [Seguridad](SECURITY.md).
