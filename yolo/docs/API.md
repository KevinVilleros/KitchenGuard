# API REST — CocinaP Web Server

El servidor web embebido corre en `http://0.0.0.0:8080` (puerto configurable).
Todos los endpoints retornan JSON, excepto `/api/stream` (MJPEG) y `/api/events` (SSE).

---

## Endpoints

### `GET /`

Información básica del servidor.

```json
{"ok": true, "app": "CocinaP", "docs": "/api/info"}
```

---

### `GET /api/info`

Información detallada del servidor.

```json
{
  "version": "1.0.0",
  "uptime": 253.09,
  "camera_ok": true,
  "fcm_enabled": false,
  "fcm_tokens": 1,
  "ips": ["192.168.1.63"],
  "port": 8080
}
```

---

### `GET /api/status`

Estado actual de detección en tiempo real. Responde cada ~100ms.

```json
{
  "fire_regions": 0,
  "smoke_regions": 0,
  "persons": 1,
  "fire_coverage": 0.0,
  "smoke_coverage": 0.0,
  "fire_stove": false,
  "pots": 0,
  "status_text": "Cocina segura",
  "last_alarm": null
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `fire_regions` | int | Cantidad de regiones de fuego detectadas |
| `smoke_regions` | int | Cantidad de regiones de humo detectadas |
| `persons` | int | Personas detectadas en zona de estufa |
| `fire_coverage` | float | Cobertura de fuego (0.0–1.0) |
| `smoke_coverage` | float | Cobertura de humo (0.0–1.0) |
| `fire_stove` | bool | Fuego detectado dentro de la zona de estufa |
| `pots` | int | Ollas detectadas (sin uso actual) |
| `status_text` | string | Texto descriptivo del estado |
| `last_alarm` | object/null | Última alarma generada (null si no hay) |

---

### `GET /api/stream`

Stream MJPEG en vivo. Retorna `multipart/x-mixed-replace; boundary=frame`.

- ~15 FPS
- JPEG quality 65
- Frame con overlay de detecciones

Para usar en Flutter:
```dart
// Usar MjpegService incluido en la app
final streamUrl = "${server.serverUrl}/api/stream";
```

---

### `GET /api/events`

Server-Sent Events (SSE) para alarmas en tiempo real.

```
data: {"_id": 1, "time": "12:34:56", "severity": "CRITICO", "message": "FUEGO DETECTADO", "source": "webui"}
data: {"_id": 2, "time": "12:35:01", "severity": "ALTO", "message": "Humo en cocina", "source": "webui"}
```

Eventos enviados cada ~500ms (solo nuevos desde último ID conocido).

Para consumir desde Flutter:
```dart
final request = http.Request('GET', Uri.parse("${api.baseUrl}/api/events"));
final response = await request.send();
response.stream
    .transform(utf8.decoder)
    .transform(const LineSplitter())
    .listen((line) {
  if (line.startsWith("data: ")) {
    final alarm = jsonDecode(line.substring(6));
    // procesar alarma
  }
});
```

---

### `GET /api/config`

Configuración actual del sistema. Retorna todas las claves de `cocinap/config.py`.

```json
{
  "CAMERA_ID": 0,
  "YOLO_CONFIDENCE": 0.4,
  "DETECTION_INTERVAL": 0.15,
  "FIRE_COVERAGE_LOW": 0.03,
  "FIRE_COVERAGE_MEDIUM": 0.08,
  "FIRE_COVERAGE_HIGH": 0.15,
  "FIRE_COVERAGE_CRITICAL": 0.25,
  "STOVE_ZONE_X": 0.25,
  "STOVE_ZONE_Y": 0.35,
  "STOVE_ZONE_W": 0.50,
  "STOVE_ZONE_H": 0.45,
  ...
}
```

---

### `POST /api/config`

Actualizar configuración. Enviar un JSON con los campos a modificar.

```json
{
  "YOLO_CONFIDENCE": 0.35,
  "STOVE_ZONE_X": 0.20,
  "STOVE_ZONE_Y": 0.30,
  "STOVE_ZONE_W": 0.60,
  "STOVE_ZONE_H": 0.50
}
```

Respuesta:
```json
{"ok": true}
```

Los cambios se persisten en `%APPDATA%/CocinaP/config.json` y se aplican en caliente.

---

### `GET /api/alarms`

Historial de alarmas (máximo 100 entradas).

```json
[
  {"_id": 1, "time": "12:34:56", "severity": "ALTO", "message": "Humo en cocina", "source": "engine"},
  {"_id": 0, "time": "12:30:00", "severity": "MEDIO", "message": "Cocina desatendida", "source": "engine"}
]
```

---

### `POST /api/register_token`

Registrar token FCM para notificaciones push.

```json
{"token": "fcm-token-aqui"}
```

Respuesta:
```json
{"ok": true}
```

---

### `POST /api/unregister_token`

Desregistrar token FCM.

```json
{"token": "fcm-token-aqui"}
```

Respuesta:
```json
{"ok": true}
```

---

## Códigos de Estado

| Código | Significado |
|---|---|
| 200 | OK |
| 400 | Bad Request (JSON inválido o faltan campos) |
| 404 | Endpoint no encontrado |
| 500 | Error interno del servidor |

## CORS

Todos los endpoints incluyen `Access-Control-Allow-Origin: *` para permitir
conexiones desde cualquier origen.
