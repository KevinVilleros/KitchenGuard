# Referencia de API REST — CocinaP (backend PC)

Documentación de la API HTTP que expone el backend de CocinaP. La app móvil la
consume en **modo conectado**.

- **Base URL:** `http://<IP-del-PC>:8080`
- **Puerto por defecto:** `8080` (`WEB_PORT`)
- **Esquema:** HTTP/1.1
- **Autenticación:** cabecera `X-API-Key` (o query param `api_key` en streams)

---

## 1. Autenticación

Todos los endpoints salvo `/` requieren una **API key**. El backend la genera la
primera vez y la guarda con hash SHA-256; el valor en claro se muestra una sola
vez (y en el diálogo de conexión del PC).

```http
X-API-Key: <tu-api-key>
```

Para streams (MJPEG/SSE), que no pueden fijar cabeceras fácilmente desde sockets
crudos, la clave se pasa como query param:

```
GET /api/stream?api_key=<tu-api-key>
```

Si la clave es inválida, la respuesta es:

```json
{ "error": "unauthorized", "message": "API key invalida" }
```

con código `401`.

---

## 2. Rate limiting

El servidor aplica límites por IP (token bucket):

- **Lecturas:** ~`rate_limit_read` peticiones por minuto.
- **Escrituras (POST):** ~`rate_limit_write` peticiones por minuto.

Al superar el límite devuelve `429` con cabecera `Retry-After`:

```json
{ "error": "rate_limited", "retry_after": 12, "message": "..." }
```

---

## 3. Cabeceras de seguridad

Todas las respuestas incluyen:

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: no-referrer
Permissions-Policy: camera=(), microphone=(), geolocation=()
Cache-Control: no-store, no-cache, must-revalidate
```

CORS: `Access-Control-Allow-Origin` restringido (no comodín).

---

## 4. Endpoints

### 4.1 `GET /`

Endpoint público de bienvenida (sin auth).

```json
{ "ok": true, "app": "CocinaP", "docs": "/api/info" }
```

---

### 4.2 `GET /api/info`

Información del servidor y estado de la conexión. Usado por la app para validar
la conexión.

**Respuesta `200`:**

```json
{
  "version": "1.0.2",
  "uptime": 123.45,
  "camera_ok": true,
  "fcm_enabled": false,
  "fcm_tokens": 0,
  "ips": ["192.168.1.20"],
  "port": 8080,
  "auth_required": true,
  "rate_limit_read": 120,
  "rate_limit_write": 30
}
```

---

### 4.3 `GET /api/status`

Estado de detección y del temporizador.

**Respuesta `200`:**

```json
{
  "fire_regions": 0,
  "smoke_regions": 0,
  "persons": 1,
  "fire_coverage": 0.0,
  "smoke_coverage": 0.0,
  "fire_stove": false,
  "pots": 0,
  "status_text": "Cocina atendida",
  "last_alarm": null,
  "timer": { "running": false, "remaining": 0 },
  "active": true,
  "alarm_config": { "unattended": true, "smoke": true, "fire": true }
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `fire_regions` | int | Regiones de fuego detectadas |
| `smoke_regions` | int | Regiones de humo detectadas |
| `persons` | int | Personas detectadas |
| `fire_coverage` | float | Proporción del encuadre con fuego |
| `smoke_coverage` | float | Proporción del encuadre con humo |
| `fire_stove` | bool | Hay fuego dentro de la zona de estufa |
| `pots` | int | Recipientes detectados en la estufa |
| `status_text` | string | Texto de estado legible |
| `last_alarm` | object\|null | Última alarma |
| `timer` | object | Estado del temporizador (`running`, `remaining`, `paused`) |
| `active` | bool | Sistema activo |
| `alarm_config` | object | Interruptores de alarmas |

---

### 4.4 `GET /api/stream`

Stream de video **MJPEG** (`multipart/x-mixed-replace; boundary=frame`).

- Frames JPEG a ~30 fps, calidad 65, ancho máximo 480 px.
- Requiere `api_key` (query param o cabecera).
- Si no hay cámara, emite frames negros.

**Nota:** conexión de larga duración; el cliente debe leer el stream de forma
continua.

---

### 4.5 `GET /api/events`

Stream de **Server-Sent Events** con las alarmas nuevas, una por evento:

```
data: {"_id": 12, "time": "14:32:05", "severity": "ALTO", "message": "Cocina desatendida", "type": "unattended"}
```

- Heartbeat cada 0.5 s.
- Requiere `api_key`.

---

### 4.6 `GET /api/config`

Devuelve la configuración actual (claves de `cocinap/config.py`).

**Respuesta `200` (fragmento):**

```json
{
  "YOLO_CONFIDENCE": 0.4,
  "DETECTION_INTERVAL": 0.15,
  "KITCHEN_TIMER_DURATION": 30,
  "ALARM_UNATTENDED_ENABLED": true,
  "ALARM_SMOKE_ENABLED": true,
  "ALARM_FIRE_ENABLED": true,
  "STOVE_ZONE_X": 0.25,
  "STOVE_ZONE_Y": 0.35,
  "STOVE_ZONE_W": 0.50,
  "STOVE_ZONE_H": 0.45
}
```

---

### 4.7 `POST /api/config`

Actualiza la configuración. Solo se aceptan claves permitidas
(`_CONFIG_KEYS`), y `STOVE_ZONE_*` debe estar entre 0 y 1.

**Cuerpo:**

```json
{ "KITCHEN_TIMER_DURATION": 45, "ALARM_SMOKE_ENABLED": false }
```

**Respuesta `200`:**

```json
{ "ok": true }
```

---

### 4.8 `GET /api/alarms`

Últimas alarmas (máximo 50).

**Respuesta `200`:**

```json
[
  { "_id": 12, "time": "14:32:05", "severity": "ALTO", "message": "Cocina desatendida", "type": "unattended" }
]
```

---

### 4.9 `POST /api/timer/start`

Inicia el temporizador de monitoreo.

**Cuerpo:** `{ "minutes": 30 }` (entre 1 y 240; por defecto `KITCHEN_TIMER_DURATION`).

**Respuesta `200`:** `{ "ok": true, "timer": { "running": true, "remaining": 1800 } }`

---

### 4.10 `POST /api/timer/pause` · `POST /api/timer/resume` · `POST /api/timer/stop`

Controlan el temporizador. Respuesta `{ "ok": true, "timer": {...} }`.

---

### 4.11 `GET /api/security/status`

Estado del subsistema de seguridad.

```json
{
  "auth_enabled": true,
  "rate_limit_read_rpm": 120,
  "rate_limit_write_rpm": 30,
  "blocked_ips": 0,
  "audit_entries": 42
}
```

---

### 4.12 `GET /api/security/audit`

Últimas 200 entradas de auditoría.

```json
{ "logs": [ { "ts": 1729000000.0, "event": "auth_ok", "ip": "192.168.1.5", "path": "/api/status" } ] }
```

---

## 5. Códigos de estado

| Código | Significado |
|---|---|
| `200` | OK |
| `400` | Cuerpo JSON inválido o parámetros fuera de rango |
| `401` | API key inválida o ausente |
| `404` | Endpoint inexistente |
| `413` | Cuerpo demasiado grande (máx. 1 MB) |
| `429` | Rate limit superado (`Retry-After`) |

---

## 6. Descubrimiento mDNS

El backend anuncia el servicio:

- **Tipo:** `_cocinap._tcp.local.`
- **Propiedades:** `version`, `auth=apikey`
- **Puerto:** `8080`

La app móvil resuelve PTR → SRV → registro A para obtener `http://IP:puerto`.

---

## 7. Ejemplos con curl

```bash
# Info del servidor
curl -H "X-API-Key: TU_CLAVE" http://192.168.1.20:8080/api/info

# Estado
curl -H "X-API-Key: TU_CLAVE" http://192.168.1.20:8080/api/status

# Iniciar temporizador 30 min
curl -X POST -H "X-API-Key: TU_CLAVE" -H "Content-Type: application/json" \
     -d '{"minutes":30}' http://192.168.1.20:8080/api/timer/start

# Ver stream MJPEG guardando un frame (primeros bytes)
curl "http://192.168.1.20:8080/api/stream?api_key=TU_CLAVE" --output frame.mjpeg
```

```powershell
# Windows PowerShell (usa curl.exe del sistema)
& C:\Windows\System32\curl.exe -H "X-API-Key: TU_CLAVE" http://192.168.1.20:8080/api/status
```

---

## 8. Modelo de datos de alarma

```json
{
  "_id": 12,
  "time": "14:32:05",
  "severity": "ALTO",
  "message": "Cocina desatendida",
  "type": "unattended"
}
```

| Campo | Valores |
|---|---|
| `severity` | `CRITICO`, `ALTO`, `MEDIO`, `BAJO` |
| `type` | `unattended`, `fire`, `smoke` |

---

## 9. Relacionado

- [Arquitectura](ARCHITECTURE.md) — flujo cliente-servidor.
- [Seguridad](SECURITY.md) — auth, rate limiting y auditoría en detalle.
