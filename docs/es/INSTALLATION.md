# Instalación y compilación — CocinaP

Guía completa para preparar, compilar e instalar CocinaP en Android, iOS y
Windows.

---

## 1. Requisitos del sistema

### Desarrollo Flutter

| Herramienta | Versión | Notas |
|---|---|---|
| Flutter SDK | 3.32+ (probado en 3.47) | Incluye Dart 3.2+ |
| Dart | 3.2+ | Incluido con Flutter |
| Android SDK | API 26+ | Con `platform-tools` (adb) |
| Java JDK | 17 o 21 | Para Gradle/Android |
| Xcode | 16+ | Solo macOS, para iOS local |
| Visual Studio | 2022 | Windows: carga **Desarrollo para el escritorio con C++** |
| Modo de desarrollador de Windows | Activado | Requerido para enlaces simbólicos de plugins |
| Git | 2.x | Control de versiones |

### Dispositivos

- **Android:** 8.0+ (API 26+), con depuración USB activada.
- **iOS:** 17.0+.
- **Windows:** 10 u 11.
- **Red:** misma LAN que la cámara IP para buscarla. Para video remoto, el
  paquete de prueba usa CocinaP Cloud y requiere internet en la PC.

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

## 4. App de escritorio Windows — compilar y ejecutar

La app de Windows es la misma aplicación Flutter que la app móvil. Usa MoveNet
Lightning mediante ONNX Runtime para detectar personas localmente.

### 4.1 Requisitos

- Windows 10 u 11.
- Flutter stable con soporte de escritorio Windows habilitado.
- Visual Studio 2022 con la carga de trabajo **Desarrollo para el escritorio
  con C++** y sus componentes predeterminados.
- Modo de desarrollador de Windows activado para que Flutter pueda crear los
  enlaces simbólicos de plugins.

Comprueba la instalación con `flutter doctor -v`.

### 4.2 Ejecutar o compilar

```powershell
cd cocinap_mobile
flutter pub get
flutter run -d windows
# O crea una versión release:
flutter build windows --release
```

El ejecutable y sus archivos de runtime quedan en
`cocinap_mobile/build/windows/x64/runner/Release/`. Para crear el paquete de
prueba con FFmpeg incluido, desde `cocinap_mobile` ejecuta:

```powershell
flutter build windows --release
.\scripts\package_windows_test.ps1
```

El ZIP generado en `build/CocinaP-Windows-x64-v1.0.15-test.zip` incluye el
codificador LGPL requerido para CocinaP Cloud. La captura de webcam está
limitada a aproximadamente un fotograma por segundo; la detección Windows usa
una pose MoveNet y no es idéntica a ML Kit móvil.

---

## 5. Video remoto desde cualquier lugar

En Windows, abre CocinaP, verifica la cámara y activa **Acceso desde cualquier
lugar** en Ajustes. En el móvil, selecciona **PC remota por la nube** y escanea
el QR que aparece en la PC. No requiere Tailscale ni cambios en el router.

El QR da acceso al video: compártelo solo con personas de confianza. La PC debe
permanecer encendida y conectada a internet. La conexión cloud es una función
de prueba; no hay gestión ni cobro de suscripciones y las alertas push en
segundo plano no están disponibles.

Ver [Manual de usuario](USER_GUIDE.md) para el uso diario.

---

## 6. Compilación de referencia (CI)

El repositorio incluye workflows en `.github/workflows/`:

| Workflow | Disparador | Resultado |
|---|---|---|
| `ios.yml` ("iOS Build CocinaP") | push a `main` con cambios en `cocinap_mobile/**` o manual | `.ipa` sin firmar (artefacto `CocinaP-iOS`) |

Ver [Pruebas y CI/CD](TESTING.md).

---

## 7. Problemas comunes de instalación

| Síntoma | Causa probable | Solución |
|---|---|---|
| `flutter doctor` marca Android | Licencias no aceptadas | `flutter doctor --android-licenses` |
| Gradle falla por Java | JDK incompatible | Usa JDK 17/21 y exporta `JAVA_HOME` |
| `adb` no encuentra el dispositivo | Depuración USB apagada | Actívala y acepta el diálogo |
| Build iOS falla | Falta de firma | Usa el `.ipa` sin firmar con Sideloadly |
| Build Windows informa que faltan enlaces simbólicos | Modo de desarrollador desactivado | Actívalo y vuelve a ejecutar `flutter pub get` |
| Build Windows no encuentra herramientas C++ | Falta la carga de trabajo de Visual Studio | Instala Visual Studio 2022 con **Desarrollo para el escritorio con C++** |

Más casos en [Solución de problemas](TROUBLESHOOTING.md).
