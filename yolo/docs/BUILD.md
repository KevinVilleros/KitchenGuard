# Build & Compilación

## Requisitos

### PC — Python
- Python 3.14+ (64-bit)
- pip
- Git
- 8 GB RAM mínimo (para PyInstaller + torch)
- 10 GB espacio libre en disco

### PC — Instalador
- Inno Setup 6+ ([descargar](https://jrsoftware.org/isdl.php))

### Móvil — Flutter
- Flutter 3.29+ ([instalar](https://docs.flutter.dev/get-started/install))
- Android SDK 36
- JDK 21 (Temurin recomendado)
- Dispositivo Android 8.0+ o emulador

---

## Compilar Ejecutable Windows

### 1. Preparar entorno

```powershell
# Clonar repositorio
git clone https://github.com/KevinVilleros/KitchenGuard
cd KitchenGuard

# Crear y activar virtualenv (opcional pero recomendado)
python -m venv venv
.\venv\Scripts\Activate.ps1

# Instalar dependencias
pip install -r requirements.txt
```

### 2. Descargar modelo YOLO

```powershell
python -c "from ultralytics import YOLO; YOLO('yolo11n.pt')"
Move-Item -Path yolo11n.pt -Destination models\yolo11n.pt
```

### 3. Compilar con PyInstaller

```powershell
python build_app.py
```

Esto genera:
```
dist/CocinaP/
├── CocinaP.exe        ← Ejecutable principal (42 MB)
└── _internal/         ← Dependencias (800+ MB)
```

### 4. Generar instalador Inno Setup

```powershell
iscc installer/CocinaP.iss
```

Esto genera:
```
dist/CocinaP_Setup_v1.0.1.exe   ← Instalador comprimido (92 MB)
```

### Build completo (automático)

```powershell
python build_all.py
```

Ejecuta pip install → PyInstaller → Inno Setup en secuencia.

---

## Compilar App Móvil (Android)

### 1. Preparar

```powershell
cd cocinap_mobile
flutter pub get
```

### 2. Probar en dispositivo

```powershell
flutter run
```

### 3. Compilar APK debug

```powershell
flutter build apk --debug
```

### 4. Compilar APK release (requiere keystore)

```powershell
# Crear keystore primero (una sola vez)
keytool -genkey -v -keystore android/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key

# Configurar android/key.properties con:
# storePassword=<password>
# keyPassword=<password>
# keyAlias=key
# storeFile=key.jks

# Compilar
flutter build apk --release
```

---

## Variables de Entorno

| Variable | Propósito |
|---|---|
| `JAVA_HOME` | JDK path (ej: `C:\tools\jdk-21`) |
| `ANDROID_HOME` | Android SDK path (ej: `C:\tools\android-sdk`) |

Agregar al PATH:
- `C:\tools\flutter\bin`

---

## Estructura del Build

```
KitchenGuard/
├── build/                  ← Temp (PyInstaller)
├── dist/                   ← Output
│   ├── CocinaP/            ← Carpeta del ejecutable
│   │   ├── CocinaP.exe     ← Entry point
│   │   └── _internal/      ← Librerías y módulos
│   └── CocinaP_Setup_*.exe ← Instalador
├── build_app.py            ← Script PyInstaller
├── build_all.py            ← Build completo
└── installer/
    └── CocinaP.iss         ← Config Inno Setup
```

---

## Notas Técnicas

- **PyInstaller --onedir** es más confiable que --onefile para librerías complejas como torch/opencv
- **--windowed** evita que la consola se muestre al usuario final
- Los módulos excluidos (scipy, pandas) reducen el tamaño ~200 MB
- matplotlib y sympy son necesarios por ultralytics/torch aunque no se usen directamente
- El path del modelo YOLO se resuelve con `sys._MEIPASS` en modo frozen
