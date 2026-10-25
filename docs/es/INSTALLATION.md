# Instalación y compilación — CocinaP

Guía completa para preparar el entorno, compilar e instalar la app móvil y el
backend del PC.

---

## 1. Requisitos del sistema

### Para desarrollar la app móvil

| Herramienta | Versión | Notas |
|---|---|---|
| Flutter SDK | 3.32+ (probado en 3.47) | Incluye Dart 3.2+ |
| Dart | 3.2+ | Incluido con Flutter |
| Android SDK | API 26+ | Con `platform-tools` (adb) |
| Java JDK | 17 o 21 | Para Gradle/Android |
| Xcode | 16+ | Solo macOS, para iOS local |
| Git | 2.x | Control de versiones |

### Para ejecutar el backend del PC

| Herramienta | Versión | Notas |
|---|---|---|
| Python | 3.10+ | Con `pip` |
| Windows | 10 u 11 | Para la GUI PySide6 |

### Dispositivos

- **Android:** 8.0+ (API 26+), con depuración USB activada.
- **iOS:** 17.0+.
- **Red:** WiFi en la misma subred que el PC (solo modo conectado).

---

## 2. Entorno de desarrollo

### 2.1 Windows (PowerShell)

```powershell
# Ruta de Flutter y JDK (ejemplo)
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
$env:Path = "C:\flutter\bin;$env:JAVA_HOME\bin;$env:Path"

# Verificar
flutter --version
flutter doctor
```

> En Windows PowerShell 5.1 no uses `&&`; encadena con `;` o `if ($?) { ... }`.

### 2.2 Verificación de Flutter

```bash
flutter doctor -v
```

Resuelve cualquier incidencia que marque `doctor` (licencias Android, dispositivos,
etc.) antes de compilar.

---

## 3. App móvil — compilar e instalar

### 3.1 Obtener dependencias

```bash
cd cocinap_mobile
flutter pub get
```

### 3.2 Ejecutar en modo desarrollo

```bash
flutter devices          # lista dispositivos conectados
flutter run              # compila y ejecuta en el dispositivo elegido
```

### 3.3 Android — APK

```bash
cd cocinap_mobile
flutter build apk --release
# Salida: build/app/outputs/flutter-apk/app-release.apk
```

Instalar por USB:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Otras variantes:

```bash
flutter build appbundle --release   # AAB para Google Play
flutter build apk --debug           # APK de depuración
```

### 3.4 iOS — compilar sin Mac (GitHub Actions)

La compilación de iOS requiere macOS con Xcode. Sin Mac, el proyecto genera el
`.ipa` **en la nube** mediante GitHub Actions:

1. Haz `push` a `main` (o ejecuta el workflow manualmente en
   `Actions → iOS Build CocinaP → Run workflow`).
2. Cuando termine, descarga el artefacto **`CocinaP-iOS`** (`.ipa` sin firmar).
3. Instálalo con **Sideloadly** en el iPhone.

Pasos detallados e imágenes: [INSTALL_IOS_WINDOWS.es.md](../INSTALL_IOS_WINDOWS.es.md).

> Nota: el `.ipa` firmado con Sideloadly (cuenta gratuita) **expira a los 7
> días**; hay que reinstalarlo. Un certificado de desarrollador de pago evita
> esa caducidad.

### 3.5 iOS — compilar en macOS

```bash
cd cocinap_mobile
flutter build ipa --release --export-method ad-hoc
# Salida: build/ios/ipa/*.ipa
```

---

## 4. Backend del PC — instalar y ejecutar

> El backend está archivado en `yolo/`. Es opcional y solo aporta detección de
> fuego/humo y el servidor para el modo conectado.

### 4.1 Crear entorno virtual e instalar dependencias

```powershell
cd yolo
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 4.2 Ejecutar

```powershell
python main.py
```

La GUI de escritorio abre con las pestañas **Cámara**, **Config** y **Alarmas**.
Al iniciar, el servidor HTTP escucha en el puerto **8080** y muestra las IPs
locales y la **API key** (generada la primera vez).

### 4.3 Empaquetar un ejecutable

```powershell
python build_app.py        # genera el .exe con PyInstaller
python build_all.py        # build completo (app + instalador)
```

---

## 5. Conectar la app móvil al PC

1. Asegura que el móvil y el PC estén en la **misma red WiFi**.
2. En el PC, abre CocinaP y localiza la **API key** (menú de conexión o consola).
3. En la app móvil, ve a la pestaña **Conectar** y elige un método:
   - **Buscar en la red** (mDNS): encuentra el PC automáticamente.
   - **Escanear QR del PC**: en el PC, pulsa "Mostrar código QR".
   - **Conectar manualmente**: introduce `http://IP:8080` y la API key.
4. Pulsa conectar. El estado debe pasar a **Conectado**.

Ver [Manual de usuario](USER_GUIDE.md) para el uso diario.

---

## 6. Compilación de referencia (CI)

El repositorio incluye workflows en `.github/workflows/`:

| Workflow | Disparador | Resultado |
|---|---|---|
| `ios.yml` ("iOS Build CocinaP") | push a `main` con cambios en `cocinap_mobile/**` o manual | `.ipa` sin firmar (artefacto `CocinaP-iOS`) |
| `python-ci.yml` | cambios en `yolo/**` | lint + tests del backend |

Ver [Pruebas y CI/CD](TESTING.md).

---

## 7. Problemas comunes de instalación

| Síntoma | Causa probable | Solución |
|---|---|---|
| `flutter doctor` marca Android | Licencias no aceptadas | `flutter doctor --android-licenses` |
| Gradle falla por Java | JDK incompatible | Usa JDK 17/21 y exporta `JAVA_HOME` |
| `adb` no encuentra el dispositivo | Depuración USB apagada | Actívala y acepta el diálogo |
| Build iOS falla | Falta de firma | Usa el `.ipa` sin firmar con Sideloadly |
| `pip install` falla | Sin compiladores | Instala Build Tools de Visual Studio |

Más casos en [Solución de problemas](TROUBLESHOOTING.md).
