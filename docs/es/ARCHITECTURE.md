# Arquitectura — CocinaP

Documento de referencia de la arquitectura del sistema CocinaP. Describe los
componentes, cómo se comunican, el flujo de datos y las decisiones estructurales.

---

## 1. Visión general

CocinaP es un sistema de **seguridad para la cocina** compuesto por dos partes:

1. **App móvil (Flutter)** — la tecnología principal. Funciona de forma
   **independiente** en Android e iOS: usa la cámara del teléfono o una cámara
   IP, y detecta personas **en el propio dispositivo** (TensorFlow Lite), sin
   necesidad de PC ni de nube.
2. **Backend Python/YOLO (opcional)** — aplicación de escritorio para Windows
   que añade detección de **fuego y humo** con un modelo YOLO, además de un
   servidor HTTP para que la app móvil se conecte a él por WiFi.

La app móvil puede operar:

- **Modo independiente (standalone):** todo el procesamiento ocurre en el móvil.
- **Modo conectado:** la app se conecta por WiFi al backend del PC y consume su
  stream de video, estado, alarmas y configuración.

```
                         ┌───────────────────────────────────────────┐
                         │               APP MÓVIL (Flutter)          │
                         │  Android / iOS                             │
                         │                                            │
   Cámara del móvil ───► │  Modo independiente                        │
   (o cámara IP)         │   • TFLite: detección de personas          │
                         │   • Temporizador de monitoreo              │
                         │   • Alarmas locales (sonido/vibración)     │
                         │                                            │
                         │  Modo conectado                            │
                         │   • mDNS discovery · QR · URL manual       │
                         │   • MJPEG stream del PC                    │
                         │   • SSE de alarmas                         │
                         └───────────────┬────────────────────────────┘
                                         │  HTTP/1.1 (WiFi LAN)
                                         │  X-API-Key
                                         ▼
                         ┌───────────────────────────────────────────┐
                         │          BACKEND PC (Python, Windows)      │
                         │  PySide6 GUI + ThreadingHTTPServer         │
                         │                                            │
   Cámara USB / IP ─────► │  YOLO11n (fuego/humo/personas)             │
                         │  Analizador de riesgo · Alarmas            │
                         │  Web UI (REST + MJPEG + SSE)               │
                         │  Seguridad: API key, rate limit, auditoría │
                         └───────────────────────────────────────────┘
```

---

## 2. Componentes

### 2.1 App móvil (`cocinap_mobile/`)

Arquitectura por capas con patrón **Provider** para el estado.

| Capa | Carpeta | Responsabilidad |
|---|---|---|
| Entrada | `lib/main.dart` | Arranque, tema, navegación (5 pestañas), tour, onboarding |
| UI | `lib/pages/` | Pantallas (Inicio, Monitoreo, Conectar, Alarmas, Ajustes) |
| UI | `lib/widgets/` | Componentes reutilizables (gráficos, MJPEG, tour) |
| Estado | `lib/providers/` | `ChangeNotifier` por dominio |
| Servicios | `lib/services/` | HTTP, mDNS, MJPEG, TFLite, notificaciones, prefs |
| Contenido | `lib/content/` | Textos bilingües ES/EN |

**Providers:**

| Provider | Responsabilidad |
|---|---|
| `ServerProvider` | Estado de conexión al PC, descubrimiento mDNS, API key, servidores recientes |
| `AlarmsProvider` | Alarmas recibidas del servidor (SSE) |
| `StandaloneProvider` | Monitoreo independiente: cámara, temporizador, detección de persona, alertas |
| `TourController` | Estado del tour guiado de la interfaz |

**Servicios:**

| Servicio | Responsabilidad |
|---|---|
| `ApiService` | Cliente HTTP de la API REST del backend (status, info, timers) |
| `DiscoveryService` | Descubrimiento mDNS de `_cocinap._tcp.local.` |
| `MjpegService` | Parser del stream MJPEG del PC |
| `PersonDetector` | Inferencia TFLite on-device (SSD MobileNet V2 / COCO) |
| `BackgroundServiceManager` | Servicio en segundo plano y notificaciones locales |
| `SettingsService` | Persistencia con `SharedPreferences` |

### 2.2 Backend PC (`yolo/`)

| Módulo | Responsabilidad |
|---|---|
| `cocinap/app.py` | GUI de escritorio (PySide6): cámara, config, alarmas |
| `cocinap/engine.py` | Motor: coordinación de detección, análisis y timer |
| `cocinap/detector/` | `detector.py` (YOLO) y `runner.py` (bucle de inferencia) |
| `cocinap/analyzer/risk_analyzer.py` | Cálculo de riesgo y alarmas (fuego/humo/desatención) |
| `cocinap/camera/handler.py` | Captura de cámara USB o IP (RTSP/HTTP) |
| `cocinap/webui.py` | Servidor HTTP: REST, MJPEG y SSE |
| `cocinap/alarm/sound_alarm.py` | Alarma sonora |
| `cocinap/security/` | Autenticación (`auth`), rate limiting, auditoría, crypto |
| `cocinap/config.py` | Configuración persistente y metadatos de parámetros |

> El backend está **archivado** dentro de `yolo/` (ver `yolo/README.md`); la app
> móvil es la tecnología activa y no depende de él en modo independiente.

---

## 3. Flujo de datos

### 3.1 Modo independiente (on-device)

```
CameraController ──frame──► PersonDetector (TFLite, SSD MobileNet v2)
                                   │
                           n personas detectadas
                                   │
                                   ▼
                          StandaloneProvider
                     (personPresent, absenceSeconds)
                                   │
              timerRunning && sin persona > umbral
                                   ▼
                    Alerta local (sonido + vibración)
                       + notificación local
```

1. La cámara produce frames en formato YUV/RGB.
2. `PersonDetector` redimensiona a `300x300x3` (uint8), ejecuta el modelo y
   obtiene hasta 20 detecciones; filtra la clase "persona".
3. `StandaloneProvider` marca `personPresent` y reinicia el contador de
   ausencia cuando hay alguien.
4. Si el temporizador está activo y transcurre el umbral sin personas, se
   dispara una alerta local.

### 3.2 Modo conectado (cliente-servidor)

```
App móvil                                  Backend PC
   │                                            │
   │── GET /api/info  (X-API-Key) ─────────────►│  valida y responde versión/IPs
   │◄───────────────────────────────────────────│
   │── GET /api/stream?api_key=… ──────────────►│  MJPEG continuo
   │◄══════════ frames JPEG ════════════════════│
   │── GET /api/events?api_key=… ──────────────►│  SSE de alarmas
   │◄══════════ data: {alarma} ═════════════════│
   │── GET /api/status ────────────────────────►│  estado de detección y timer
   │── POST /api/timer/start ──────────────────►│  control del temporizador
```

- La conexión se establece por **mDNS** (automático), **QR** (payload
  `url|api_key`) o **URL manual**.
- Todas las peticiones llevan la cabecera `X-API-Key`. Los streams (MJPEG/SSE)
  la pasan como query param `api_key` porque los sockets crudos no pueden
  fijar cabeceras de forma sencilla.

---

## 4. Modelos de IA

| Contexto | Modelo | Entrada | Salidas | Dónde |
|---|---|---|---|---|
| App móvil | SSD MobileNet V2 (COCO) | `1x300x300x3` uint8 | Hasta 20 detecciones | On-device (TFLite) |
| Backend PC | YOLO11n (`yolo11n.pt`) | Imagen redimensionada | fuego, humo, personas | PC |

- En el móvil solo se detectan **personas** (para el modo desatendido). Fuego y
  humo requieren el PC conectado.
- En el backend, `DETECT_SCALE` y `YOLO_IMGSZ` controlan el coste/velocidad de
  la inferencia; el modelo corre en CPU por defecto.

---

## 5. Persistencia

### App móvil (`SharedPreferences`)

| Clave | Uso |
|---|---|
| `server_url`, `recent_servers` | Última URL y servidores recientes |
| `api_key` | API key del backend |
| `auto_connect` | Auto-conexión al arrancar |
| `standalone_*` | Duración, umbrales, confianza, fuente y URL de cámara |
| `has_seen_install_guide`, `has_seen_app_tour` | Flags de primer uso |
| `app_language` | Idioma de la interfaz (es/en) |

### Backend PC

- `%APPDATA%\CocinaP\config.json` — parámetros y `STOVE_ZONE`.
- `%APPDATA%\CocinaP\logs\` — `eventos.log` y `crash.log`.
- `%APPDATA%\CocinaP\firebase-key.json` — clave de FCM (opcional).

---

## 6. Comunicación de red

- **Transporte:** HTTP/1.1 sobre WiFi en red local (LAN confiable).
- **MJPEG:** `multipart/x-mixed-replace` a ~30 fps, JPEG calidad 65, ancho máx.
  480 px en el lado del servidor.
- **SSE:** `text/event-stream` con heartbeats cada 0.5 s.
- **mDNS:** servicio `_cocinap._tcp.local.` con propiedades `version` y `auth`.
- **Puerto por defecto:** 8080 (`WEB_PORT`).

> Seguridad: el servidor está diseñado para una **LAN confiable**. No debe
> exponerse a Internet. Ver [SEGURIDAD](SECURITY.md).

---

## 7. Restricciones de plataforma

| Plataforma | Notificaciones en segundo plano | Notas |
|---|---|---|
| Android | Sí (servicio en primer plano) | Requiere permisos de notificación y datos |
| iOS | Solo con app abierta | Limitaciones del sistema para segundo plano |

La detección on-device y las notificaciones locales no usan Firebase (se
eliminó FCM del cliente móvil para permitir compilar sin `google-services.json`).

---

## 8. Diagrama de despliegue

```
                 ┌─────────────┐        ┌─────────────┐
                 │  Smartphone │        │  Smartphone │
                 │   Android   │        │     iOS     │
                 │  (Flutter)  │        │  (Flutter)  │
                 └──────┬──────┘        └──────┬──────┘
                        │  WiFi LAN (opcional) │
                        └──────────┬───────────┘
                                   │ HTTP :8080
                          ┌────────▼─────────┐
                          │   PC Windows     │
                          │  Backend CocinaP │
                          │  (Python/YOLO)   │
                          └────────┬─────────┘
                                   │ USB / RTSP / HTTP
                          ┌────────▼─────────┐
                          │  Cámara          │
                          │  (USB o IP)      │
                          └──────────────────┘
```

---

## 9. Estructura de carpetas (resumen)

```
KitchenGuard/
├── cocinap_mobile/     # App Flutter (tecnología principal)
├── yolo/               # Backend Python/YOLO archivado
├── docs/               # Documentación (es/ y en/)
├── .github/workflows/  # CI: iOS build + Python CI
├── CHANGELOG.md
└── LICENSE
```

Ver [Guía de desarrollo](DEVELOPMENT.md) para el detalle de cada archivo.
