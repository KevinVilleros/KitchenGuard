# Manual de usuario — CocinaP

Guía de uso de la aplicación móvil **CocinaP** y del sistema completo.

---

## 1. Qué hace CocinaP

CocinaP vigila tu cocina y te avisa si queda **desatendida**. Usa la cámara de
tu teléfono o una cámara IP y detecta personas directamente en el dispositivo.

- **Modo local:** el teléfono usa su propia cámara o una cámara IP de la red
  local. El flujo local existente no requiere un PC.
- **Cámara Windows remota (opcional):** el teléfono recibe video de CocinaP en
  una PC Windows. Tailscale debe estar instalado en la PC y el teléfono, ambos
  conectados a la misma tailnet privada; consulta los pasos siguientes. Las
  fuentes locales siguen disponibles sin Tailscale.

---

## 2. Primer uso

La primera vez que abres la app:

1. Aparece un **onboarding** con varias páginas: qué es CocinaP, tus objetivos,
   cómo funciona y cómo conectar una cámara.
2. Se muestra una **guía de instalación y colocación de la cámara**.
3. Al entrar a la app, un **tour guiado** resalta cada una de las 5 pestañas
   (Inicio, Monitoreo, Conectar, Alarmas, Ajustes) con explicaciones breves.

Puedes repetir el tour cuando quieras: **Ajustes → Tour de la interfaz**.
Cambiar de idioma: **Ajustes → Idioma** (Español / English).

---

## 3. Las 5 pestañas

| Pestaña | Para qué sirve |
|---|---|
| **Inicio** | Panel gráfico: estado, objetivos, cómo funciona y accesos rápidos |
| **Monitoreo** | Vigila la cocina con la cámara del móvil o una cámara IP |
| **Conectar** | Conecta la app al PC (QR, mDNS o manual) |
| **Alarmas** | Historial de alarmas recibidas del PC en tiempo real |
| **Ajustes** | Preferencias, fuente de cámara, monitoreo, idioma y ayuda |

---

## 4. Monitoreo (modo independiente)

Es la función principal sin PC.

### 4.1 Elegir la fuente de cámara

En **Monitoreo**, toca el icono **Dispositivos** (barra superior) o el botón
**"Cambiar dispositivo o cámara"**. Se abre una hoja con las fuentes:

- **Cámara del móvil:** usa la cámara del teléfono.
- **Cámara IP:** toca **Configurar** y busca cámaras ONVIF en el Wi-Fi. El
  teléfono y la cámara deben estar en la misma red y ONVIF habilitado. Selecciona
  la cámara e introduce sus credenciales. Si no aparece, puedes introducir una
  URL completa HTTP/MJPEG o RTSP del manual o de la app de la cámara; una IP
  sola no basta. En iOS, la búsqueda automática ONVIF por multicast requiere
  una autorización de Apple que esta versión no incluye. Las credenciales se
  guardan de forma segura en el dispositivo.
  ONVIF y RTSP pueden requerir credenciales distintas; usa las de RTSP cuando
  la app las solicite. Si falla ONVIF, puedes probar la ruta RTSP `/stream2`;
  también puedes tocar el lápiz junto a la cámara encontrada para editar una
  URL sugerida con su IP. Las rutas sugeridas son ejemplos comunes, no garantizan
  compatibilidad. Consulta la URL RTSP en la app oficial, ajustes web o manual
  de la cámara; la lista de dispositivos del router normalmente solo muestra
  su IP.
- **Cámara remota de Windows (opcional):** recibe video desde CocinaP en una PC
  Windows. Requiere Tailscale en la PC y el móvil, conectados a la misma tailnet;
  consulta los pasos siguientes. Las fuentes locales siguen disponibles sin
  Tailscale.

La hoja incluye un **tutorial breve** con las fuentes disponibles.

### 4.2 Configurar acceso remoto opcional

1. Deja una PC Windows encendida en casa e instala Tailscale tanto en esa PC
   como en el teléfono. Inicia sesión en ambos con la misma cuenta/red privada.
2. Abre CocinaP en Windows, selecciona la cámara y activa **Permitir acceso
   remoto** en Ajustes. Mantén la app abierta y el monitoreo activo.
3. En PowerShell ejecuta `tailscale serve --bg 8080`. Usa
   `tailscale serve status` para ver la dirección HTTPS privada terminada en
   `.ts.net`.
4. Conecta Tailscale en el teléfono. En Ajustes de CocinaP móvil, elige la
   fuente de cámara del PC remoto, ingresa la dirección HTTPS y la clave API
   que se muestra en Ajustes de Windows, y prueba la conexión.

No configures redirección de puertos del router ni uses Tailscale Funnel. La PC
debe permanecer encendida, sin suspensión, conectada a Tailscale y a la cámara.
Las instantáneas de webcam Windows se envían a aproximadamente un fotograma
por segundo. La detección del teléfono solo funciona mientras la app móvil está
abierta; las alertas del escritorio no se sincronizan con el teléfono. Cuando no
uses el modo remoto, puedes desactivarlo con `tailscale serve reset`.

### 4.3 Iniciar el monitoreo

1. Elige la duración del **plazo de monitoreo** (por ejemplo 15, 30 o 60 min).
2. Pulsa **Iniciar**. El temporizador empieza la cuenta atrás.
3. La app vigila si hay personas en el encuadre:
   - **Persona detectada:** la cocina está atendida.
   - **Sin persona:** tras el tiempo configurado, se dispara una **alerta local**
     (sonido y vibración) y una notificación.
4. Puedes **Pausar**, **Reanudar** o **Detener** en cualquier momento.

### 4.4 Ajustes del monitoreo

En **Ajustes** puedes configurar:

| Ajuste | Descripción |
|---|---|
| Duración del monitoreo | Minutos del plazo |
| Segundos sin persona para alertar | Umbral de ausencia |
| Minutos de peligro | Tiempo considerado peligroso sin atender |
| Confianza de detección | Sensibilidad del detector (0.2–0.9) |
| Fuente de cámara | Móvil, IP local o PC remota |

---

## 5. Video remoto de escritorio (opcional)

Para ver la cámara del PC cuando el teléfono está fuera de casa, ambos
dispositivos deben estar conectados a la misma red privada Tailscale:

1. Instala Tailscale en el PC Windows y en el teléfono e inicia sesión en la
   misma red privada.
2. Abre CocinaP en Windows, selecciona la cámara y activa **Permitir acceso
   remoto** en Ajustes. Mantén la app abierta y el monitoreo activo.
3. En PowerShell del PC ejecuta `tailscale serve --bg 8080`. Usa
   `tailscale serve status` para encontrar la dirección HTTPS privada terminada
   en `.ts.net`.
4. Copia la clave API que se muestra en Ajustes de Windows. En **Ajustes** del
   móvil, elige la fuente de cámara del PC remoto, ingresa la dirección HTTPS y
   la clave, y prueba la conexión.

No expongas el puerto 8080 mediante el router ni uses Tailscale Funnel. El PC
debe permanecer encendido y CocinaP ejecutándose. Las instantáneas de webcam
se envían aproximadamente a un fotograma por segundo. El teléfono ejecuta su
detector de personas mientras la app está abierta; las alertas del escritorio
no se sincronizan con el móvil.

---

## 6. Alarmas

La app genera alertas locales de cocina desatendida con sonido y vibración
mientras el monitoreo está activo. No se ofrece detección de fuego ni humo.

---

## 7. Ajustes

| Sección | Opciones |
|---|---|
| Monitoreo | Duración, umbrales, confianza |
| Cámara | Fuente (móvil, cámara IP o video remoto de escritorio opcional) |
| Interfaz | Idioma (ES/EN), repetir tour |
| Guías | Manual, guía de cámaras, términos |
| Acerca de | Versión y créditos |

---

## 8. Consejos de uso

- **Colocación de la cámara:** enfoca la zona de cocción completa, con buena luz
  y sin obstáculos.
- **Cámara IP:** la detección ONVIF busca en la red local. Si no encuentra la
  cámara, comprueba que ONVIF esté habilitado y que ambos dispositivos estén en
  el mismo Wi-Fi; también puedes introducir la URL HTTP/MJPEG o RTSP manualmente.
- **Ahorro de batería:** el monitoreo con cámara consume batería; mantén el
  teléfono cargando en sesiones largas.
- **Fuego y humo:** CocinaP no los detecta.

---

## 9. Privacidad

En modo local, las imágenes se procesan en el teléfono o se solicitan
directamente a la cámara IP local. El video remoto de escritorio se transmite
por tu red privada Tailscale. Ver [Política de privacidad](../legal/PRIVACY_POLICY.es.md).

---

## 10. Atajos y detalles

- **Idioma:** Español por defecto, cambia a English en Ajustes.
- **Segundo plano:** en Android, el monitoreo con la cámara del teléfono usa un
  servicio visible con notificación permanente. Las cámaras IP requieren que
  CocinaP permanezca abierta. En iPhone, la cámara y la detección se pausan al
  salir de la app; el monitoreo continuo requiere un host externo y
  notificaciones push, aún no disponibles. El modo Android debe validarse en
  un teléfono físico y el sistema puede limitarlo por ahorro de batería.
- **Reconexión de cámara:** el stream IP se reintenta automáticamente y puedes
  usar el botón de actualizar. Al volver a la app, se reconecta si iOS o Android
  había pausado el video.
