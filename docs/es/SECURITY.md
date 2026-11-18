# Seguridad — CocinaP

Modelo de seguridad, controles implementados y buenas prácticas de operación.

---

## 1. Principios

1. **Privacidad por diseño:** las imágenes se procesan localmente en el teléfono
   o el PC Windows; CocinaP no las sube a un servicio en la nube.
2. **Superficie mínima:** el host Windows ofrece únicamente estado de cámara y
   endpoints MJPEG autenticados.
3. **Red confiable:** el acceso remoto debe pasar por Tailscale Serve en una
   tailnet privada; no expongas el puerto 8080 a Internet.
4. **Autenticación:** el host requiere una clave API generada para ambos endpoints.

---

## 2. Modelo de amenazas (resumen)

| Activo | Amenaza | Mitigación |
|---|---|---|
| Stream de cámara | Acceso no autorizado | API key obligatoria en cada endpoint |
| Credenciales | Exposición de la API key | Clave aleatoria de 256 bits en almacenamiento seguro |
| Red | Exposición a Internet | Tailscale Serve; nunca publiques el puerto 8080 |

Fuera de alcance (documentado): ataques físicos al dispositivo, robo del
teléfono desbloqueado, red WiFi ya comprometida.

---

## 3. Autenticación del host Windows

- Se genera una clave criptográficamente aleatoria de 32 bytes y se guarda con
  `flutter_secure_storage`.
- `/api/info` y `/api/stream` requieren la clave en la cabecera `X-API-Key`.
- La comparación es en tiempo constante para claves de la longitud esperada;
  la clave nunca se incluye en la URL.
- El host solo acepta peticiones `GET` a esas dos rutas.
- El host aún no implementa límite de peticiones por cliente ni auditoría.

---

## 4. Seguridad en la app móvil

- La API key del host Windows se guarda en almacenamiento seguro de la plataforma.
- Una API key heredada de `SharedPreferences` se migra una vez y luego se elimina de las preferencias normales.
- El cliente remoto solo acepta direcciones HTTPS Tailscale terminadas en `.ts.net`.
- No hay telemetría ni envío de imágenes a la nube.
- FCM eliminado: las notificaciones son **locales** (Android en segundo plano;
  iOS solo con app abierta).

---

## 5. Buenas prácticas de operación

- **No** publiques el puerto 8080 en el router (sin port forwarding).
- Usa Tailscale Serve en la tailnet privada; no uses Tailscale Funnel para la
  API CocinaP. Protege la cuenta Tailscale y revoca dispositivos que ya no
  deban conectarse.
- Usa una **red WiFi de confianza** y WPA2/WPA3.
- Desactiva inmediatamente el acceso remoto si se expone la clave del host. La
  interfaz de Ajustes aún no permite rotar la clave.
- Mantén actualizados el sistema operativo, Flutter y las dependencias.

---

## 6. Reportar una vulnerabilidad

No abras un issue público. Envía un correo a **kevinvilleros77@gmail.com** con:

- Descripción detallada.
- Pasos de reproducción.
- Prueba de concepto (si es posible).
- Versión afectada.

Confirmación en **48 horas**. Ver también [SECURITY.md](../../SECURITY.md) en la
raíz.

---

## 7. Versiones soportadas

| Versión | Soportada |
|---|---|
| 1.0.x | Sí |

---

Ver también: [Referencia de API](API.md), [Arquitectura](ARCHITECTURE.md).
