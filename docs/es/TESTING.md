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

Las pruebas dirigidas de red/cámara:

```bash
flutter test test/mjpeg_frame_parser_test.dart test/onvif_camera_service_test.dart
```

Cubren el parseo de frames MJPEG y el filtrado de respuestas ONVIF para aceptar
endpoints locales y rechazar destinos remotos o URLs con credenciales embebidas.
No sustituyen la prueba física de negociación ONVIF, autenticación, video RTSP,
compatibilidad por modelo ni reconexión ante pérdida de red.

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
| Jobs | `validate-mobile` (análisis y pruebas), `build-android` (APK sin firmar), `build-unsigned` (.ipa sin firmar) y `build-signed` (opcional) |
| Artefactos | `CocinaP-Android-unsigned` (contiene `app-release.apk`) y `CocinaP-iOS` (contiene `CocinaP-unsigned.ipa`) |

Ambos builds de plataforma dependen de `validate-mobile`. El workflow ejecuta
`flutter analyze` y `flutter test` antes de generar los artefactos.

### Android

El job `build-android` espera la validación, instala Java 17, configura Flutter
estable, obtiene las dependencias y ejecuta `flutter build apk --release`. Este
workflow no tiene configurada la firma de producción Android, por lo que genera
un APK sin firmar que no está listo para tiendas. El artefacto
`CocinaP-Android-unsigned` se publica si el build termina correctamente,
aunque falle posteriormente un build iOS.

Pasos del job Android:

1. `checkout`.
2. `actions/setup-java` (Java 17).
3. `subosito/flutter-action` (canal stable).
4. `flutter pub get`.
5. `flutter build apk --release`.
6. Subida del artefacto APK sin firmar.

El job `build-unsigned` compila y empaqueta la app iOS como
`CocinaP-unsigned.ipa`.

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

#### Firma Android de producción

El tipo `release` ya no usa la clave de depuración. Sin configuración de firma,
Gradle genera un artefacto `release` sin firmar y muestra una advertencia; no
se puede subir ese artefacto a Google Play.

1. Crea y guarda una clave de carga (upload key) fuera del repositorio. Guárdala
   de forma segura y conserva una copia de respaldo; perderla puede impedir
   futuras actualizaciones de la app.
2. Crea `cocinap_mobile/android/key.properties` con las propiedades
   `storeFile`, `storePassword`, `keyAlias` y `keyPassword`. `storeFile` es
   relativo a `cocinap_mobile/android`; por ejemplo, `upload-keystore.jks`
   si guardas ahí el archivo.
3. Mantén fuera de Git tanto `key.properties` como el archivo `.jks` o
   `.keystore`. No compartas contraseñas ni claves en el código, el chat o los
   logs de CI.
4. Genera el AAB con `flutter build appbundle --release` y verifica la firma
   antes de subirlo a Play Console.

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
- [ ] Matriz real de cámaras ONVIF, RTSP y MJPEG probada y publicada; registrar
  modelos incompatibles y pruebas negativas.
- [ ] Licencias y avisos de libmpv, FFmpeg/codecs y dependencias nativas
  revisados antes de distribución comercial.
- [ ] Firma de producción configurada; no usar la clave `debug`.
- [ ] Política de privacidad, identidad del editor y fichas de tienda
  completadas y revisadas legalmente.
- [ ] Permisos de cámara, red local y segundo plano probados en dispositivo.
- [ ] Los errores conocidos tienen propietario, impacto y plan de corrección.
- [ ] `ruff check` y `pytest` en verde (backend).
- [ ] Versión bump en `pubspec.yaml` y backend.
- [ ] Entrada nueva en `CHANGELOG.md`.
- [ ] Workflow de iOS completado con éxito.
- [ ] Artefacto `.ipa` verificado.

---

Ver también: [Guía de desarrollo](DEVELOPMENT.md), [Instalación](INSTALLATION.md).
