# Pruebas y CI/CD — CocinaP

Estrategia de pruebas y automatización (integración/entrega continua) del
proyecto.

---

## 1. Estrategia de pruebas

| Capa | Herramienta | Ubicación | Qué cubre |
|---|---|---|---|
| App móvil | `flutter_test` | `cocinap_mobile/test/` | Widgets y arranque |
| Backend | `pytest` | `yolo/tests/` | Config, motor, analizador, seguridad |
| Análisis estático | `flutter analyze`, `ruff` | — | Lint y tipos |

---

## 2. Pruebas de la app móvil

```bash
cd cocinap_mobile
flutter test
```

Prueba de humo incluida en `test/widget_test.dart`: verifica que la app arranca.

Para ejecutar una sola prueba:

```bash
flutter test test/widget_test.dart
```

Cobertura:

```bash
flutter test --coverage
# genera coverage/lcov.info
```

---

## 3. Pruebas del backend

```bash
cd yolo
pytest
```

Suites existentes:

| Archivo | Área |
|---|---|
| `test_config.py` | Carga y guardado de configuración |
| `test_engine.py` | Motor de detección/estado |
| `test_analyzer.py` | Analizador de riesgo |
| `test_runner.py` | Bucle de inferencia |
| `test_security.py` | Auth, rate limit y auditoría |
| `test_package.py` | Empaquetado |

Con cobertura:

```bash
pytest --cov=cocinap yolo/tests
```

---

## 4. Análisis estático y formato

```bash
# App móvil
cd cocinap_mobile
flutter analyze
dart format --set-exit-if-changed .

# Backend
ruff check yolo/
ruff format --check yolo/
```

---

## 5. Integración continua (GitHub Actions)

Workflows en `.github/workflows/`:

### 5.1 `ios.yml` — "iOS Build CocinaP"

| Aspecto | Detalle |
|---|---|
| Disparador | push a `main`/`master` con cambios en `cocinap_mobile/**` o `.github/workflows/ios.yml`; o manual (`workflow_dispatch`) |
| Runners | `ubuntu-latest` para Android y `macos-latest` para iOS |
| Jobs | `build-android` (APK), `build-unsigned` (.ipa sin firmar) y `build-signed` (opcional) |
| Artefactos | `CocinaP-Android` (contiene `app-release.apk`) y `CocinaP-iOS` (contiene `CocinaP-unsigned.ipa`) |

### Android

El job `build-android` instala Java 17, configura Flutter estable, obtiene las
dependencias y ejecuta `flutter build apk --release`. El APK se publica siempre
que el build termine correctamente, aunque falle posteriormente un build iOS.

Pasos del job principal:

1. `checkout`.
2. `subosito/flutter-action` (canal stable).
3. `flutter pub get`.
4. `flutter build ios --release --no-codesign`.
5. Empaquetado `Payload/` → `CocinaP-unsigned.ipa`.
6. Subida del artefacto.

El job `build-signed` solo firma si están definidos los secretos
`IOS_CERTIFICATE`, `IOS_CERTIFICATE_PASSWORD` y `IOS_PROVISIONING_PROFILE`; en
caso contrario se omite.

### 5.2 `python-ci.yml` — "Python CI (yolo backend)"

| Aspecto | Detalle |
|---|---|
| Disparador | cambios en `yolo/**` |
| `working-directory` | `yolo` |
| Acciones | lint (`ruff`) y tests (`pytest`) del backend |

---

## 6. Entrega continua (releases)

### App móvil

- **Android:** `flutter build appbundle --release` genera el AAB para Google
  Play.
- **iOS:** el `.ipa` se produce en CI; se distribuye mediante Sideloadly
  (cuenta gratuita: expira a los 7 días) o TestFlight/App Store con firma.

### Backend

- `python build_app.py` empaqueta el `.exe` (PyInstaller).
- `python build_all.py` hace el build completo (app + instalador).

---

## 7. Versionado

- Se sigue **Semantic Versioning** (`MAJOR.MINOR.PATCH`).
- La versión del backend está en `yolo/cocinap/__init__.py` y
  `yolo/cocinap/resources/version.txt`.
- La versión de la app está en `cocinap_mobile/pubspec.yaml`.
- Los cambios se registran en [CHANGELOG.md](../CHANGELOG.md) (formato Keep a
  Changelog).

---

## 8. Lista de verificación antes de un release

- [ ] `flutter analyze` sin incidencias.
- [ ] `flutter test` en verde.
- [ ] APK e IPA reproducibles desde artefactos documentados.
- [ ] Matriz Android e iPhone completada en dispositivos reales.
- [ ] Permisos de cámara, red local y segundo plano probados en dispositivo.
- [ ] Los errores conocidos tienen propietario, impacto y plan de corrección.
- [ ] `ruff check` y `pytest` en verde (backend).
- [ ] Versión bump en `pubspec.yaml` y backend.
- [ ] Entrada nueva en `CHANGELOG.md`.
- [ ] Workflow de iOS completado con éxito.
- [ ] Artefacto `.ipa` verificado.

---

Ver también: [Guía de desarrollo](DEVELOPMENT.md), [Instalación](INSTALLATION.md).
