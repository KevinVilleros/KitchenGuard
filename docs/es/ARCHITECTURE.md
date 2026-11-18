# Arquitectura — CocinaP

Documento de referencia de la arquitectura del sistema CocinaP. Describe los
componentes, cómo se comunican, el flujo de datos y las decisiones estructurales.

---

## 1. Visión general

CocinaP es una aplicación Flutter para **Android, iOS y Windows**. Permite
monitorear localmente con la cámara del dispositivo o una cámara IP y, de
forma opcional, ver la cámara de Windows desde un móvil vinculado por QR a
través de CocinaP Cloud. La detección se ejecuta localmente: ML Kit Pose
Detection en Android/iOS y MoveNet Lightning mediante ONNX Runtime en Windows.

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
                         │  Video remoto cloud (opcional)              │
                         │   • QR y tokens vía Cloudflare Worker       │
                         │   • Video en vivo por LiveKit               │
                         └───────────────┬────────────────────────────┘
                                         │  LiveKit (stream + estado)
                                         │  HTTPS (tokens)
                                         ▼
                  ┌─────────────────────────────────────┐
                  │   CocinaP (Flutter, Windows)        │
                  │ Cámara local + MoveNet              │
                  │ MJPEG local → FFmpeg/OpenH264       │
                  └──────────────────┬──────────────────┘
                                     │ RTMPS
                                     ▼
                              LiveKit Cloud
                                     ▲
                                     │ HTTPS: token del móvil
                           Cloudflare Worker
                                     ▲
                                     │ HTTPS: QR/credenciales
                               App móvil
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
| `RemoteCloudService` | Registra el equipo y solicita tokens cloud |
| `RemoteCloudHostService` | Inicia el servidor MJPEG local y los publicadores de LiveKit |
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

Al activar el acceso cloud, `RemoteCameraServer` sirve localmente el MJPEG que
FFmpeg publica por RTMPS a LiveKit; otro publicador envía el estado del
monitoreo. El teléfono solicita un token al gateway Cloudflare y se conecta a
LiveKit para recibir el video. El PC debe permanecer encendido, conectado a
internet y con CocinaP ejecutándose. Tailscale sigue disponible como acceso
avanzado independiente.

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

### 3.2 Video remoto por nube (opcional)

```
App móvil          Cloudflare Worker         LiveKit          CocinaP Windows
   │                     │                     │                     │
   │── credenciales ────►│                     │                     │
   │◄── token ───────────│                     │                     │
   │──────────────────── conectar ────────────►│                     │
   │◄════════ video + estado ═════════════════│◄──── RTMPS ─────────│
```

- La PC registra su dispositivo una vez y usa una clave de propietario para
  solicitar la publicación; el QR contiene una clave distinta de solo lectura.
- El gateway emite tokens de corta duración. El video transita por LiveKit;
  no se debe describir como procesamiento exclusivamente local.
- El teléfono y el PC deben tener internet. El QR es una credencial y no debe
  publicarse. La prueba no incluye pagos, revocación en la app ni push fiable.

---

## 4. Modelos de IA

| Contexto | Modelo | Entrada | Salidas | Dónde |
|---|---|---|---|---|
| Android/iOS | ML Kit Pose Detection | Fotograma de cámara | Poses de personas | On-device |
| Windows | MoveNet Lightning (`movenet_lightning.onnx`) | `1x192x192x4` uint8 | Una pose de 17 puntos | On-device (ONNX Runtime) |

La detección es local. Cuando se activa el acceso remoto cloud, el video en
vivo se transmite por LiveKit; CocinaP no tiene una función de grabación. Las
instantáneas de webcam Windows limitan su stream a aproximadamente un
fotograma por segundo.

---

## 5. Persistencia

### App móvil (`SharedPreferences`)

| Clave | Uso |
|---|---|
| `server_url` | Dirección HTTPS de Windows remoto |
| `standalone_*` | Duración, umbrales, confianza, fuente y URL de cámara |
| `desktop_host_api_key` | Clave del host Windows en almacenamiento seguro |
| `desktop_remote_host_enabled` | Indica si inicia el host MJPEG Windows |
| `cloud_gateway_url`, `cloud_device_id` | Dirección e identificador del dispositivo |
| `cloud_owner_key`, `cloud_viewer_key` | Claves cloud en almacenamiento seguro |
| `cloud_host_enabled` | Indica si publica la cámara por cloud |
| `has_seen_install_guide`, `has_seen_app_tour` | Flags de primer uso |
| `app_language` | Idioma de la interfaz (es/en) |

La clave del host Windows se guarda mediante almacenamiento seguro de la
plataforma y solo se muestra en Ajustes para configurar el teléfono.

---

## 6. Comunicación de red

- **Host Windows:** HTTP en el puerto 8080, enlazado a loopback por Flutter.
- **Acceso cloud:** tokens de host y móvil emitidos por el gateway; video y
  estado viajan por LiveKit.
- **Tailscale avanzado:** el host MJPEG local usa el puerto 8080; no expongas
  ese puerto mediante redirección del router o Funnel.
- **Endpoints locales:** `GET /api/info` y `GET /api/stream`.
- **MJPEG:** sigue la fuente seleccionada; las instantáneas de webcam Windows
  se capturan aproximadamente a un fotograma por segundo.

> Seguridad: no compartas el QR ni expongas el puerto 8080 a Internet. Ver
> [SEGURIDAD](SECURITY.md).

---

## 7. Restricciones de plataforma

| Plataforma | Notificaciones en segundo plano | Notas |
|---|---|---|
| Android | Depende del servicio activo | No hay push remoto garantizado |
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
                        │ LiveKit / HTTPS    │
                        └──────────┬─────────┘
                                   │ RTMPS
                          ┌────────▼─────────┐
                          │   PC Windows     │
                          │ CocinaP + FFmpeg │
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
