# Arquitectura del Sistema

## Visión General

CocinaP es un sistema cliente-servidor híbrido donde la PC funciona como servidor
de detección y la app móvil como cliente de monitoreo remoto. La GUI nativa en
Windows proporciona la interfaz principal para configuración local.

## Componentes

### 1. Módulo de Cámara (`cocinap/camera/`)

```
CameraHandler
├── start() → abre cámara con OpenCV (CAP_DSHOW)
├── _capture_loop() → thread daemon capturando frames
├── get_frame() → retorna último frame (thread-safe)
└── stop() → libera recursos
```

- Usa `cv2.VideoCapture` con `CAP_DSHOW` para baja latencia en Windows
- Frame size configurable via `config.py` (default: 1280×720)
- Hilo separado para no bloquear el loop principal

### 2. Módulo de Detección (`cocinap/detector/`)

```
DetectionRunner
├── Inicia hilo background de detección
├── pull callback: obtiene frame de la cámara
├── submit_frame: envía frame al detector YOLO
│
Detector
├── YOLO11n (Ultralytics) para detección de objetos
│   └── Clases: persona, fuego (fire), humo (smoke)
├── Análisis CV post-detección:
│   ├── Fuego: análisis de color HSV + cobertura + parpadeo
│   ├── Humo: análisis de textura + bordes + color grisáceo
│   └── Persona: verificación en zona de estufa
```

**Pipeline de detección:**
1. Frame capturado por la cámara
2. Redimensionado a `DETECT_SCALE` (25%) para YOLO
3. YOLO11n inference a `imgsz=320`
4. Post-procesamiento CV sobre los resultados
5. Resultados disponibles via `get_latest()`

### 3. Motor Principal (`cocinap/engine.py`)

```
CocinaPEngine (Fachada)
├── get_frame_cb: callback para obtener frame
├── DetectionRunner: maneja detección asíncrona
├── RiskAnalyzer: evalúa riesgo según reglas
├── WebUI: servidor HTTP embebido (opcional)
├── SoundAlarm: alerta sonora asíncrona
│
├── start() / stop()
├── analyze() → procesa detecciones, genera alertas
├── get_status() → texto y color de estado
├── draw() → overlay en frame para display
└── get_unattended() → detección de cocina desatendida
```

### 4. Análisis de Riesgo (`cocinap/analyzer/`)

```
RiskAnalyzer
├── Niveles: OK → BAJO → MEDIO → ALTO → CRÍTICO
├── Factores evaluados:
│   ├── Cobertura de fuego en zona de estufa
│   ├── Persistencia temporal del fuego
│   ├── Cobertura de humo
│   ├── Textura y bordes de humo
│   ├── Persona presente/ausente
│   └── Cocina desatendida (fuego + sin persona)
└── Cooldown entre alertas para evitar spam
```

### 5. Servidor Web (`cocinap/webui.py`)

```
WebUI
├── ThreadingHTTPServer en puerto 8080
├── Endpoints REST:
│   ├── GET /api/info       → información del servidor
│   ├── GET /api/status     → estado actual de detección
│   ├── GET /api/config     → configuración actual
│   ├── POST /api/config    → actualizar configuración
│   ├── GET /api/alarms     → historial de alarmas
│   ├── POST /api/register_token   → registrar FCM token
│   └── POST /api/unregister_token → desregistrar FCM token
├── Streams:
│   ├── GET /api/stream     → MJPEG stream (~15 FPS)
│   └── GET /api/events     → SSE para alarmas en tiempo real
└── mDNS (Zeroconf): CocinaP anunciado como _cocinap._tcp.local.
```

### 6. GUI Nativa (`cocinap/app.py`)

```
MainWindow (PySide6)
├── CameraTab: video en vivo con overlay de detección
├── ConfigTab: ajuste de zona de estufa + parámetros
├── AlarmsTab: historial de alarmas
├── System tray: minimizar a bandeja
└── Menú: Archivo (Salir), Ayuda (Acerca de)
```

### 7. App Móvil (`cocinap_mobile/`)

```
Providers (Provider state management)
├── ServerProvider: conexión HTTP + mDNS discovery
├── AlarmsProvider: stream SSE de alarmas
└── ConfigProvider: GET/POST configuración remota

Services
├── ApiService: llamadas HTTP a API REST
├── DiscoveryService: mDNS discovery (multicast_dns)
├── MjpegService: parser de stream MJPEG
├── FcmService: Firebase Cloud Messaging (opcional)
└── SettingsService: SharedPreferences persistencia

Pages
├── DiscoveryPage: auto-descubrimiento mDNS / conexión manual
├── DashboardPage: MJPEG stream + status polling
├── AlarmsPage: historial de alarmas en vivo
├── ConfigPage: configuración remota de parámetros
└── SettingsPage: auto-conexión, servidor guardado
```

## Flujo de Datos

```
Cámara ──frame──▶ DetectionRunner ──detecciones──▶ CocinaPEngine
                                                       │
                                                       ├──▶ GUI (display + alarmas)
                                                       ├──▶ SoundAlarm (beep)
                                                       ├──▶ WebUI (REST + SSE + MJPEG)
                                                       │       │
                                                       │       ├──▶ App Móvil (Dashboard)
                                                       │       ├──▶ App Móvil (Alarmas SSE)
                                                       │       └──▶ FCM (push opcional)
                                                       └──▶ config.py (persistencia JSON)
```

## Hilos y Concurrencia

| Hilo | Propósito |
|---|---|
| Main (Qt) | Event loop de PySide6 GUI |
| Camera capture | Lectura continua de frames (daemon) |
| Detection runner | YOLO inference loop (daemon) |
| Web server | ThreadingHTTPServer (daemon, maneja múltiples conexiones) |
| Sound alarm | Beep asíncrono vía `ctypes.windll.kernel32.Beep` |
