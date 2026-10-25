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

- Confirma que la URL es **MJPEG** (p. ej. `http://IP:puerto/video`).
- Las cámaras que solo ofrecen **RTSP** no funcionan directamente en el móvil.
- Verifica que el teléfono y la cámara están en la misma red.
- Comprueba la URL en un navegador del PC.

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

## 4. Backend (PC)

### `pip install` falla al compilar dependencias

Instala **Build Tools para Visual Studio** (requerido por algunos paquetes como
numpy/opencv/PySide6).

### El modelo YOLO no carga

- Comprueba que existe `yolo/models/yolo11n.pt`.
- En modo empaquetado, el modelo se resuelve vía `sys._MEIPASS`.

### No hay señal de cámara en el PC

- Verifica la cámara en **Config** (USB o URL RTSP/HTTP).
- Cierra otras apps que usen la cámara.
- Reinicia la app tras cambiar el dispositivo/URL (requiere reinicio).

### El puerto 8080 está ocupado

Cámbialo en `config.json` (`WEB_PORT`) o libera el puerto.

---

## 5. Preguntas frecuentes

**¿Necesito el PC para usar la app?**
No. El modo independiente funciona solo con el teléfono (detección de personas).

**¿Detecta fuego y humo sin PC?**
No. Fuego y humo requieren el backend del PC conectado.

**¿Se suben mis videos a Internet?**
No. Todo el procesamiento es local (dispositivo o tu PC).

**¿Por qué el IPA caduca?**
Sideloadly con cuenta gratuita firma por 7 días. Un certificado de pago evita la
caducidad.

**¿Funciona en segundo plano?**
Android sí (servicio en primer plano). iOS solo con la app abierta.

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
