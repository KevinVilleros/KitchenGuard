# Arquitectura — CocinaP

Documento de referencia de la arquitectura del sistema CocinaP. Describe los
componentes, cómo se comunican, el flujo de datos y las decisiones estructurales.

---

## 1. Visión general

CocinaP es una aplicación Flutter para **Android, iOS y Windows**. Permite
monitorear localmente con la cámara del dispositivo o una cámara IP y compartir
de forma segura la cámara seleccionada en Windows con un teléfono por
Tailscale. La detección se ejecuta localmente: ML Kit Pose Detection en
Android/iOS y MoveNet Lightning mediante ONNX Runtime en Windows.

```
                         ┌───────────────────────────────────────────┐
                         │              COCINAP (Flutter)             │
                         │  Android / iOS / Windows                   │
                         │                                            │
   Cámara del móvil ───► │  Modo independiente                        │
   (o cámara IP)            │   • ML Kit / MoveNet: detección             │
                         │   • Temporizador de monitoreo              │
                         │   • Alarmas locales (sonido/vibración)     │
                         │                                            │
                         │  Video remoto de Windows (opcional)         │
                         │   • Red privada Tailscale                  │
                         │   • HTTPS + X-API-Key                      │
                         │   • Stream MJPEG autenticado del PC         │
                         └───────────────┬────────────────────────────┘
                                         │  HTTPS mediante Tailscale Serve
                                         │  X-API-Key
                                         ▼
                         ┌───────────────────────────────────────────┐
                         │          CocinaP (Flutter, Windows)         │
                         │  Cámara local y monitoreo                  │
                         │                                            │
   Cámara USB / IP ─────► │  MoveNet Lightning (personas)             │
                         │  Endpoint MJPEG autenticado                │
                         │  Tailscale Serve (HTTPS privado)            │
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
| Servicios | `lib/services/` | HTTP, ONVIF, MJPEG, detección, notificaciones y ajustes |
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
| `RemoteDesktopService` | Valida la dirección Tailscale Serve y prueba el API del PC |
| `MjpegService` | Recibe el stream MJPEG de la cámara seleccionada |
| `PersonDetector` | ML Kit en Android/iOS; delega a MoveNet en Windows |
| `WindowsPersonDetector` | Inferencia MoveNet Lightning mediante ONNX Runtime |
| `RemoteCameraServer` | Host MJPEG autenticado de Windows en el puerto 8080 |
| `BackgroundServiceManager` | Servicio en segundo plano y notificaciones locales |
| `SettingsService` | Persistencia con `SharedPreferences` |

### 2.2 Plataforma Windows

El runner Windows está en `cocinap_mobile/windows/` y comparte la interfaz
Flutter, el estado, las fuentes de cámara, el temporizador y las alertas. La
webcam se captura en instantáneas de aproximadamente un fotograma por segundo,
ya que `camera_windows` no ofrece un stream de imágenes. MoveNet Lightning
detecta una persona por fotograma y su modelo/salida difieren de ML Kit móvil.

Al activar el acceso remoto, `RemoteCameraServer` expone `/api/info` y
`/api/stream` en el puerto 8080. Tailscale Serve proporciona el endpoint HTTPS
privado que utiliza el teléfono. El PC debe permanecer encendido y CocinaP
ejecutándose.

---

## 3. Flujo de datos

### 3.1 Modo independiente (on-device)

```
CameraController ──frame──► PersonDetector (ML Kit / MoveNet)
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
2. `PersonDetector` ejecuta localmente el detector de poses de cada plataforma
   y devuelve cajas de persona y puntuaciones de confianza.
3. `StandaloneProvider` marca `personPresent` y reinicia el contador de
   ausencia cuando hay alguien.
4. Si el temporizador está activo y transcurre el umbral sin personas, se
   dispara una alerta local.

### 3.2 Video remoto de escritorio (opcional)

```
App móvil                                  CocinaP Windows
   │                                            │
   │── GET /api/info  (X-API-Key) ─────────────►│  valida y responde estado de cámara
   │◄───────────────────────────────────────────│
   │── GET /api/stream (X-API-Key) ────────────►│  MJPEG continuo
   │◄══════════ frames JPEG ════════════════════│
```

- El usuario configura en la app una dirección HTTPS de Tailscale Serve
  terminada en `.ts.net` y la clave API de Windows. El teléfono también
  debe estar conectado a la misma tailnet.
- El cliente móvil envía la clave en la cabecera `X-API-Key`, no en la URL.
  Esta función consume solo el endpoint de información y el stream; las
  alarmas y controles del PC no están integrados en la app móvil.

---

## 4. Modelos de IA

| Contexto | Modelo | Entrada | Salidas | Dónde |
|---|---|---|---|---|
| Android/iOS | ML Kit Pose Detection | Fotograma de cámara | Poses de personas | On-device |
| Windows | MoveNet Lightning (`movenet_lightning.onnx`) | `1x192x192x4` uint8 | Una pose de 17 puntos | On-device (ONNX Runtime) |

La detección es local; el video remoto usa Tailscale y no envía imágenes a un
servicio en la nube de CocinaP. Las instantáneas de webcam Windows limitan su
stream a aproximadamente un fotograma por segundo.

---

## 5. Persistencia

### App móvil (`SharedPreferences`)

| Clave | Uso |
|---|---|
| `server_url` | Dirección HTTPS de Windows remoto |
| `standalone_*` | Duración, umbrales, confianza, fuente y URL de cámara |
| `desktop_host_api_key` | Clave del host Windows en almacenamiento seguro |
| `desktop_remote_host_enabled` | Indica si inicia el host MJPEG Windows |
| `has_seen_install_guide`, `has_seen_app_tour` | Flags de primer uso |
| `app_language` | Idioma de la interfaz (es/en) |

La clave del host Windows se guarda mediante almacenamiento seguro de la
plataforma y solo se muestra en Ajustes para configurar el teléfono.

---

## 6. Comunicación de red

- **Host Windows:** HTTP en el puerto 8080, enlazado a loopback por Flutter.
- **Stream móvil remoto:** HTTPS mediante Tailscale Serve, autenticado con
  `X-API-Key`; no expongas el puerto con redirección del router o Funnel.
- **Endpoints:** `GET /api/info` y `GET /api/stream`.
- **MJPEG:** sigue la fuente seleccionada; las instantáneas de webcam Windows
  se capturan aproximadamente a un fotograma por segundo.

> Seguridad: no expongas el puerto 8080 a Internet ni uses Tailscale Funnel.
> Ver [SEGURIDAD](SECURITY.md).

---

## 7. Restricciones de plataforma

| Plataforma | Notificaciones en segundo plano | Notas |
|---|---|---|
| Android | Sí (servicio en primer plano) | Requiere permisos de notificación y datos |
| iOS | Solo con app abierta | Limitaciones del sistema para segundo plano |
| Windows | Mientras la app está ejecutándose | El PC debe permanecer encendido; webcam a ~1 FPS |

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
                        │ HTTPS Tailscale      │
                        └──────────┬───────────┘
                                   │ HTTP :8080
                          ┌────────▼─────────┐
                          │   PC Windows     │
                          │ CocinaP Flutter  │
                          │ MoveNet + MJPEG  │
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
├── cocinap_mobile/     # App Flutter para Android, iOS y Windows
├── docs/               # Documentación (es/ y en/)
├── .github/workflows/  # CI: builds móviles y CodeQL
├── CHANGELOG.md
└── LICENSE
```

Ver [Guía de desarrollo](DEVELOPMENT.md) para el detalle de cada archivo.
