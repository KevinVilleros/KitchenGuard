# Política de Privacidad — CocinaP

**Última actualización:** [DD/MM/AAAA]

---

## 1. Introducción

CocinaP ("nosotros", "la aplicación", "el Servicio") monitorea la cocina,
detecta personas en la cámara y alerta cuando parece estar desatendida. No
detecta fuego ni humo.

Esta Política de Privacidad explica qué datos tratamos, cómo los usamos y qué derechos tienes como usuario.

**Nota legal:** Este documento es informativo y de ayuda. No constituye asesoramiento legal. Si tu uso de la aplicación implica obligaciones específicas en tu país (por ejemplo, normativa de videovigilancia o protección de datos como el GDPR en la Unión Europea), te recomendamos consultar con un profesional del derecho.

**Editor de la aplicación:**
- Nombre / Razón social: [Nombre legal de la empresa o persona]
- Correo de contacto: [correo electrónico]
- Dirección: [dirección postal]
- Sitio web: No disponible actualmente

---

## 2. Principio fundamental: procesamiento local en tu dispositivo

En modo local, el video se procesa directamente en el dispositivo. Si activas
**Acceso desde cualquier lugar** en Windows, la PC transmite el video en vivo
por internet a través de CocinaP Cloud y LiveKit para que el móvil vinculado
pueda verlo. También se comparte el estado del monitoreo (por ejemplo, cámara
activa, detección de persona y temporizador) para sincronizar la vista móvil.
El gateway de CocinaP Cloud usa Cloudflare Workers para la vinculación y los
tokens de acceso. CocinaP no tiene una función para grabar ni guardar ese
video, pero la transmisión sí pasa por infraestructura de terceros;
su tratamiento y retención también dependen de las condiciones de esos
proveedores. Puedes seguir usando los modos locales sin activar la nube.
La detección de personas se ejecuta localmente en el teléfono o PC.

Puedes consultar esta implementación técnica en el manual y la
[arquitectura](../es/ARCHITECTURE.md).

---

## 3. Qué datos y permisos utiliza la aplicación

La aplicación puede solicitar los siguientes permisos y tratar los siguientes datos, únicamente para las finalidades descritas:

### 3.1 Permisos de cámara
- **Finalidad:** capturar el video en vivo de la cocina para analizar la presencia de focos de riesgo y de personas.
- **Nota:** CocinaP no ofrece grabación de video. Si habilitas el acceso cloud,
  el video en vivo se transmite desde la PC por LiveKit hasta el móvil
  vinculado (ver apartado 5).

### 3.2 Permisos de almacenamiento
- **Finalidad:** guardar la configuración de la aplicación (preferencias, URLs de cámaras, ajustes de detección) de manera local en tu dispositivo.

### 3.3 Permisos de notificaciones
- **Finalidad:** mostrarte alertas locales (sonido y vibración) cuando la aplicación detecta una situación de riesgo, como una cocina desatendida.
- Estas notificaciones se generan y se muestran en el propio dispositivo.

### 3.4 Datos de configuración
- Las preferencias que introduces (p. ej., duración del monitoreo, tiempo de alerta, confianza de detección, configuración de la cámara IP) se guardan **localmente** en tu dispositivo.

### 3.5 Uso de la cámara de terceros (cámaras IP)
- La aplicación puede descubrir cámaras ONVIF anunciadas en tu red local o
  conectarse a un stream RTSP/HTTP-MJPEG que tú configures. Las credenciales
  ONVIF se usan para solicitar el stream en la red local; la URL del stream,
  incluidas las credenciales cuando corresponda, se guarda en el almacenamiento
  seguro del dispositivo. El video se analiza localmente.
- **Responsabilidad del usuario:** eres responsable de tener autorización para conectarte a esas cámaras y de cumplir con las leyes de privacidad y videovigilancia aplicables en tu jurisdicción (p. ej., informar a las personas que puedan ser captadas, y no instalar las cámaras en zonas donde la expectativa de privacidad sea alta, como baños o dormitorios).

---

## 4. Detección de personas e imágenes

La aplicación usa modelos locales de visión por computadora para determinar si
hay una persona en el campo de visión de la cámara: ML Kit Pose Detection en
Android/iOS y MoveNet Lightning mediante ONNX Runtime en Windows. El objetivo es
avisarte si la cocina queda desatendida.

- **Procesamiento local:** el modelo se ejecuta en el dispositivo. No se almacena ni se transmite el registro de momentos en que se detecta o no una persona, salvo el historial de alertas local.
- **No se crean perfiles:** no usamos la detección para crear perfiles de comportamiento, identificación biométrica ni seguimiento de individuos.
- **Historial de alertas:** la aplicación mantiene un historial limitado de alertas, almacenado localmente, para informarte de los eventos de riesgo.

---

## 5. Compartir datos con terceros

**No vendemos ni alquilamos** tus datos personales.

En el modo local, la aplicación no transmite el video analizado. Si activas el
modo cloud, CocinaP Cloud (gateway en Cloudflare Workers) recibe identificadores
del dispositivo y credenciales de vinculación para emitir tokens de acceso; el
video y el estado del monitoreo se envían por LiveKit entre la PC y el móvil
vinculado. El móvil también puede enviar comandos para iniciar, pausar o
detener el temporizador. El QR contiene una clave privada de visualización:
compártelo solo con personas de confianza. La PC y el móvil guardan sus
credenciales en el almacenamiento seguro del sistema operativo. Las
condiciones de tratamiento y retención de Cloudflare y LiveKit también aplican
a sus servicios.

La versión de prueba no gestiona suscripciones ni procesa pagos.

### Sobre las notificaciones push (información adicional)
La versión actual utiliza notificaciones locales y no integra notificaciones
push remotas fiables para el monitoreo en segundo plano. El comportamiento de
las notificaciones depende de la plataforma, los permisos concedidos y de que
la aplicación permanezca activa.

---

## 6. Retención de datos

- Los datos de configuración se conservan en tu dispositivo hasta que los borres o desinstales la aplicación.
- Los datos de conexión cloud necesarios para la vinculación pueden permanecer
  en los servicios de Cloudflare y LiveKit conforme a sus políticas de
  retención; la versión de prueba no ofrece una herramienta para revocar
  dispositivos vinculados ni borrar esos registros desde la app.
- El historial visible de alertas de la sesión es temporal y puede perderse al cerrar la app; la versión actual no ofrece un historial persistente ni una función para exportarlo.
- Para el borrado total, puedes desinstalar la aplicación. Si has sincronizado con un servidor propio, elimina los datos de ese servidor y revoca las conexiones/cámaras configuradas.

**Derecho al olvido:** puedes solicitar la eliminación de cualquier dato que pudiera obrar en poder del editor escribiendo al correo de contacto indicado al inicio de esta política.

---

## 7. Seguridad

Adoptamos medidas técnicas y organizativas razonables para proteger los datos tratados de forma local, incluyendo el cifrado de la configuración cuando corresponda y el uso de autenticación para el acceso de la aplicación a tus cámaras.

Sin embargo, ten en cuenta que ninguna transmisión ni almacenamiento digital es completamente seguro. Te recomendamos proteger el acceso a tu dispositivo.

---

## 8. Privacidad de los menores

La aplicación está dirigida a mayores de edad responsables de un hogar. No recopilamos de forma intencionada datos de niños. Si eres padre, madre o tutor y crees que un menor ha facilitado datos, ponte en contacto con nosotros para que los eliminemos.

---

## 9. Tus derechos

Según la legislación aplicable (especialmente el GDPR en la UE y el Reglamento General de Protección de Datos), puedes ejercer los siguientes derechos, en la medida en que sean aplicables:

- **Acceso:** conocer qué datos tratamos.
- **Rectificación:** corregir datos inexactos.
- **Supresión / borrado:** solicitar la eliminación de datos.
- **Oposición / limitación del tratamiento.**
- **Portabilidad** de los datos.
- **Revocar el consentimiento** en cualquier momento.
- Presentar una **reclamación** ante la autoridad de protección de datos de tu país.

Para ejercer estos derechos, escríbenos al correo de contacto indicado al inicio de esta política.

---

## 10. Pendiente antes de publicar

Este archivo sigue siendo una plantilla: reemplaza todos los campos entre
corchetes, confirma las prácticas reales de cada plataforma y somételo a
revisión legal antes de distribuir la app.

## 11. Cambios en esta política

Podemos actualizar esta Política de Privacidad para reflejar cambios en la aplicación o en la normativa. Cuando lo hagamos, actualizaremos la fecha de "última actualización" al inicio del documento y, cuando sea relevante, lo notificaremos dentro de la propia aplicación.

---

## 11. Contacto

Si tienes preguntas sobre esta Política de Privacidad, el tratamiento de tus datos o el cumplimiento normativo, puedes contactarnos en:

- **Correo electrónico:** [correo electrónico]
- **Dirección:** [dirección postal]
- **Asunto sugerido:** "Privacidad / Protección de datos"

---

*CocinaP — seguridad inteligente para tu cocina.*