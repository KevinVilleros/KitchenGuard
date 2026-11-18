# Solución de problemas (FAQ) — CocinaP

Errores frecuentes y cómo resolverlos, tanto en la app móvil como en el backend.

---

## 1. App móvil — compilación

### `flutter doctor` reporta problemas de Android

```bash
flutter doctor --android-licenses
```

Acepta las licencias y vuelve a ejecutar `flutter doctor`.

### Error de Gradle relacionado con Java

Causa: JDK incompatible o `JAVA_HOME` ausente.

```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Usa **JDK 17 o 21**.

### `adb` no detecta el dispositivo

- Activa **Depuración USB** en el teléfono.
- Acepta el diálogo "¿Permitir depuración USB?".
- Prueba otro cable/puerto o `adb kill-server` y `adb start-server`.

### El APK no se instala (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`)

Firma distinta entre versiones. Desinstala la anterior:

```bash
adb uninstall com.cocinap.mobile
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

---

## 2. App móvil — errores en ejecución

### "No Material widget found"

Ocurre si un `InkWell`/botón se usa sin un ancestro `Material`. En el proyecto ya
se corrigió envolviendo el tour en `Material(type: MaterialType.transparency)`.
Si reaparece tras un cambio, revisa el widget nuevo y envuélvelo en `Material`.

### Recuadro rojo/amarillo con "RenderFlex overflowed"

Un `Row`/`Column` se desborda. Soluciones aplicadas en el proyecto:

- `FittedBox` con padding en anillos/tarjetas.
- `maxLines` + `TextOverflow.ellipsis`.
- Evitar `Expanded`/`IntrinsicHeight` combinados en timelines.

Al añadir UI, prueba en pantallas pequeñas (~411x921 lógicos).

### La cámara IP no muestra imagen

- Confirma que el teléfono y la cámara están en la misma Wi-Fi/LAN y que el
  router muestra la cámara conectada.
- La búsqueda automática encuentra cámaras que anuncian **ONVIF**; en los
  ajustes de la cámara activa ONVIF si el fabricante ofrece esa opción.
- Si no aparece, la cámara puede no admitir ONVIF o el router puede aislar a los
  dispositivos Wi-Fi. Prueba la opción manual solo si tienes la URL **RTSP** o
  **HTTP/MJPEG** completa; la IP por sí sola no identifica el stream.
- Si aparece pero falla ONVIF, toca el lápiz junto a la cámara para usar la IP
  encontrada y editar rutas RTSP de ejemplo. Prueba la ruta y las credenciales
  RTSP indicadas en la app oficial, la página de configuración o el manual; las
  rutas sugeridas pueden no corresponder al modelo.
- V380 Pro es el nombre de una app y no garantiza que todos los modelos
  asociados expongan ONVIF/RTSP. El modelo **AIT36106** no se ha validado con
  CocinaP.
- En iPhone, esta versión no puede buscar ONVIF por multicast porque requiere
  una autorización de Apple que no está incluida. Vuelve al campo manual y usa
  una URL de stream compatible.

### No puedo conectar con CocinaP Windows desde fuera de casa

- Comprueba que Tailscale aparece conectado en el teléfono y en la PC y que
  ambos están en la misma red privada.
- En la PC, confirma que CocinaP está abierto, que el acceso remoto esté
  activado en Ajustes y ejecuta
  `tailscale serve status`. Usa la dirección HTTPS completa terminada en
  `.ts.net`; la app rechaza HTTP y direcciones públicas.
- Copia de nuevo la clave API desde Ajustes de Windows. La app la envía por
  encabezado HTTPS; no la pegues en la URL.
- No abras ni reenvíes el puerto 8080 del router y no uses Tailscale Funnel.
- Mantén la PC Windows encendida y el monitoreo activo. Las alertas del
  escritorio no se sincronizan con el teléfono.

### La detección de personas no alerta

- Asegura que el **temporizador** está iniciado.
- Ajusta **Confianza** (baja si no detecta, sube si hay falsos positivos).
- Revisa el umbral **Segundos sin persona para alertar**.
- Verifica que la cámara enfoca correctamente la zona.

### Las notificaciones de fondo no llegan en iOS

Limitación del sistema: en iOS las notificaciones locales funcionan **solo con
la app abierta**. Android sí admite segundo plano (servicio en primer plano).

---

## 3. Conexión al PC

### La app no encuentra el PC (mDNS)

- Verifica que ambos están en la **misma subred**.
- Algunos routers bloquean mDNS; usa **QR** o **conexión manual**.
- En el PC, revisa que el servidor está activo y muestra las IPs.

### `401 unauthorized` al conectar

La **API key** no coincide. Cópiala del PC (se muestra en el diálogo de conexión)
y vuelve a introducirla en Ajustes.

### `429 rate_limited`

Demasiadas peticiones seguidas. Espera el tiempo de `Retry-After` y reintenta.

### El stream MJPEG se corta

- Puede ser inestabilidad de la WiFi.
- El servidor limita a 480 px de ancho para ahorrar ancho de banda.
- Reintenta la conexión; la app puede reconectarse automáticamente.

---

## 4. App de Windows

### El build solicita el modo de desarrollador

Activa el modo de desarrollador de Windows y vuelve a ejecutar `flutter pub get`.

### El build de Windows no encuentra herramientas C++

Instala Visual Studio 2022 con la carga de trabajo **Desarrollo para el
escritorio con C++**.

### No carga el modelo MoveNet

Confirma que el paquete incluya `assets/models/movenet_lightning.onnx` y vuelve
a compilar después de cambiar dependencias. Consulta el error en el log de
depuración de Flutter.

### No hay señal de cámara en Windows

- Revisa los permisos de cámara en **Configuración > Privacidad y seguridad**.
- Cierra otras apps que usen la webcam y vuelve a seleccionar la fuente.
- La webcam se captura por instantáneas (~1 FPS); usa una cámara IP para un
  stream continuo de mayor frecuencia.

### El stream remoto no está disponible

- Mantén CocinaP ejecutándose en el PC y comprueba que la cámara esté activa.
- Confirma Tailscale en ambos dispositivos y que `tailscale serve status`
  muestre la dirección `.ts.net` esperada.
- Verifica la clave API y no expongas el puerto 8080 mediante el router.

---

## 5. Preguntas frecuentes

**¿Necesito el PC para usar la app?**
No. El modo independiente funciona solo con el teléfono (detección de personas).

**¿Detecta fuego y humo sin PC?**
No. Actualmente CocinaP solo detecta personas.

**¿Se suben mis videos a Internet?**
No. Todo el procesamiento es local (dispositivo o tu PC).

**¿Por qué el IPA caduca?**
Sideloadly con cuenta gratuita firma por 7 días. Un certificado de pago evita la
caducidad.

**¿Funciona en segundo plano?**
Android usa un servicio en primer plano y puede reconectar el video al volver a
la app. iOS suspende la conexión de cámara en segundo plano: mantén la app
abierta y vuelve a ella para reconectar el stream.

**¿Puedo usar varias cámaras?**
Puedes cambiar entre cámara del móvil, IP y PC desde **Monitoreo**.

---

## 6. Recopilar información de diagnóstico

- **App móvil:** captura de pantalla del error y pasos para reproducirlo.
- **Backend:** `%APPDATA%\CocinaP\logs\crash.log` y `eventos.log`.
- Versión: en la app (**Acerca de**) y en el backend (`/api/info`).

Al reportar, incluye versión, plataforma y pasos de reproducción.

---

Ver también: [Instalación](INSTALLATION.md), [Manual de usuario](USER_GUIDE.md).
