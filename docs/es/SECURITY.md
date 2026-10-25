# Seguridad — CocinaP

Modelo de seguridad, controles implementados y buenas prácticas de operación.

---

## 1. Principios

1. **Privacidad por diseño:** las imágenes se procesan **en el dispositivo** o
   en **tu propio PC**. No se envían a servidores externos.
2. **Superficie mínima:** el backend expone una API REST pequeña y auditada.
3. **Red confiable:** el servidor está pensado para una **LAN doméstica**. No
   debe exponerse a Internet.
4. **Defensa en profundidad:** autenticación, límite de peticiones, validación de
   entrada y auditoría.

---

## 2. Modelo de amenazas (resumen)

| Activo | Amenaza | Mitigación |
|---|---|---|
| Video de la cámara | Acceso no autorizado | API key obligatoria |
| API del PC | Fuerza bruta / abuso | Rate limiting + bloqueo por IP + auditoría |
| Configuración | Manipulación de parámetros | Lista blanca de claves + rangos validados |
| Credenciales | Robo de API key | Hash SHA-256 en disco, comparación en tiempo constante |
| Red | Exposición a Internet | Escucha en LAN; no publicar el puerto 8080 |

Fuera de alcance (documentado): ataques físicos al dispositivo, robo del
teléfono desbloqueado, red WiFi ya comprometida.

---

## 3. Autenticación (backend)

- API key generada al primer arranque.
- Guardada **hasheada con SHA-256**; nunca en claro en disco.
- Comparación **en tiempo constante** (evita ataques de temporización).
- Enviada por cabecera `X-API-Key` (o `api_key` en streams).
- Fallos de autenticación se registran en la auditoría.

Código relacionado: `yolo/cocinap/security/auth.py`,
`yolo/cocinap/security/crypto.py`.

---

## 4. Rate limiting y bloqueo

- Límite por IP con **token bucket**, separado para lecturas y escrituras.
- Al superarlo: `429` + `Retry-After`.
- Las IPs abusivas pueden bloquearse; los buckets se limpian periódicamente.

Código: `yolo/cocinap/security/rate_limiter.py`.

---

## 5. Validación de entrada

- Cuerpo JSON: debe ser un objeto; si no, `400`.
- Tamaño máximo de cuerpo: **1 MB** (`413` si se supera).
- Claves de configuración: **lista blanca** (`_CONFIG_KEYS`) con patrón
  `^[A-Z_]{3,40}$`.
- `STOVE_ZONE_*` limitado a `[0, 1]`; valores numéricos validados por tipo.
- Parámetros de temporizador limitados a `[1, 240]` minutos.

---

## 6. Cabeceras y CORS

- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: no-referrer`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`
- `Cache-Control: no-store, no-cache, must-revalidate`
- CORS restringido (no comodín).

---

## 7. Auditoría

Se registran (código: `yolo/cocinap/security/audit.py`):

- Arranque y parada del servidor.
- Autenticaciones correctas y fallidas.
- Superación de rate limit.
- Cambios de configuración (valor anterior y nuevo).
- Eventos de registro/eliminación de tokens.

Consultable vía `GET /api/security/audit` y `GET /api/security/status`.

---

## 8. Seguridad en la app móvil

- La API key se guarda en almacenamiento seguro de la plataforma (Keystore o Keychain).
- Una API key heredada de `SharedPreferences` se migra una vez y luego se elimina de las preferencias normales.
- Las conexiones se realizan a la URL configurada o descubierta por mDNS.
- No hay telemetría ni envío de imágenes a la nube.
- FCM eliminado: las notificaciones son **locales** (Android en segundo plano;
  iOS solo con app abierta).

---

## 9. Buenas prácticas de operación

- **No** publiques el puerto 8080 en el router (sin port forwarding).
- Usa una **red WiFi de confianza** y WPA2/WPA3.
- Rota la API key si sospechas que se filtró (elimínala del PC y regenérala).
- Mantén actualizados el sistema operativo, Flutter y las dependencias.
- Revisa la auditoría ante comportamientos extraños.

---

## 10. Reportar una vulnerabilidad

No abras un issue público. Envía un correo a **kevinvilleros77@gmail.com** con:

- Descripción detallada.
- Pasos de reproducción.
- Prueba de concepto (si es posible).
- Versión afectada.

Confirmación en **48 horas**. Ver también [SECURITY.md](../SECURITY.md) en la
raíz y [SECURITY.md](../../SECURITY.md).

---

## 11. Versiones soportadas

| Versión | Soportada |
|---|---|
| 1.0.x | Sí |

---

Ver también: [Referencia de API](API.md), [Arquitectura](ARCHITECTURE.md).
