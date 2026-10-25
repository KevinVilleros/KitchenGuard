# Manual de usuario — CocinaP

Guía de uso de la aplicación móvil **CocinaP** y del sistema completo.

---

## 1. Qué hace CocinaP

CocinaP vigila tu cocina y te avisa si queda **desatendida**. Usa la cámara de
tu teléfono o una cámara IP y detecta personas directamente en el dispositivo.

- **Modo independiente:** solo con tu teléfono. No necesita PC ni Internet.
- **Modo conectado:** si tienes el PC con CocinaP, la app se conecta por WiFi y
  añade la cámara del PC y las alarmas de **fuego y humo**.

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
- **Cámara IP:** introduce la URL del stream (por ejemplo
  `http://192.168.1.50:8080/video` o una URL MJPEG).
- **PC con CocinaP:** si está conectado, abre la cámara del PC; si no, te lleva
  a **Conectar**.

La hoja incluye un **tutorial breve** con las tres formas de conectar una
cámara.

### 4.2 Iniciar el monitoreo

1. Elige la duración del **plazo de monitoreo** (por ejemplo 15, 30 o 60 min).
2. Pulsa **Iniciar**. El temporizador empieza la cuenta atrás.
3. La app vigila si hay personas en el encuadre:
   - **Persona detectada:** la cocina está atendida.
   - **Sin persona:** tras el tiempo configurado, se dispara una **alerta local**
     (sonido y vibración) y una notificación.
4. Puedes **Pausar**, **Reanudar** o **Detener** en cualquier momento.

### 4.3 Ajustes del monitoreo

En **Ajustes** puedes configurar:

| Ajuste | Descripción |
|---|---|
| Duración del monitoreo | Minutos del plazo |
| Segundos sin persona para alertar | Umbral de ausencia |
| Minutos de peligro | Tiempo considerado peligroso sin atender |
| Confianza de detección | Sensibilidad del detector (0.2–0.9) |
| Fuente de cámara | Móvil o IP |

---

## 5. Conectar con el PC (modo conectado)

Si tienes el PC con CocinaP en la misma red WiFi:

1. Ve a la pestaña **Conectar**.
2. Elige un método:

   | Método | Cómo se usa |
   |---|---|
   | **Buscar en la red** | Pulsa buscar; encuentra el PC por mDNS |
   | **Escanear QR** | En el PC pulsa "Mostrar código QR" y escanéalo |
   | **Manual** | Escribe `http://IP:8080` y la API key |

3. Cuando el estado sea **Conectado**, la pestaña **Alarmas** y la cámara del PC
   quedan disponibles.

La app recuerda el último servidor y puede reconectarse automáticamente.

---

## 6. Alarmas

La pestaña **Alarmas** muestra el historial en tiempo real (recibido por SSE del
PC). Cada alarma incluye:

- **Hora**
- **Severidad:** CRÍTICO, ALTO, MEDIO, BAJO
- **Mensaje** y **tipo** (fuego, humo, cocina desatendida)

Además de las alarmas del PC, en modo independiente la app genera **alertas
locales** de cocina desatendida con sonido y vibración.

---

## 7. Ajustes

| Sección | Opciones |
|---|---|
| Conexión | Servidor, API key, auto-conexión, servidores recientes |
| Monitoreo | Duración, umbrales, confianza |
| Cámara | Fuente (móvil/IP), URL |
| Interfaz | Idioma (ES/EN), repetir tour |
| Guías | Manual, guía de cámaras, términos |
| Acerca de | Versión y créditos |

---

## 8. Consejos de uso

- **Colocación de la cámara:** enfoca la zona de cocción completa, con buena luz
  y sin obstáculos.
- **Cámara IP:** usa una URL MJPEG accesible desde la red local; evita cámaras
  que solo ofrecen RTSP (el móvil usa MJPEG).
- **Ahorro de batería:** el monitoreo con cámara consume batería; mantén el
  teléfono cargando en sesiones largas.
- **Fuego y humo:** requieren el PC conectado (la app móvil sola detecta solo
  personas).

---

## 9. Privacidad

Las imágenes se procesan **en el dispositivo** o en tu propio PC; no se envían a
servidores externos. Ver [Política de privacidad](../legal/PRIVACY_POLICY.es.md).

---

## 10. Atajos y detalles

- **Idioma:** Español por defecto, cambia a English en Ajustes.
- **Notificaciones:** Android permite avisos en segundo plano; iOS solo con la
  app abierta.
- **Reconexión:** al iniciar, la app intenta conectarse al último servidor y, si
  falla, busca en la red.
