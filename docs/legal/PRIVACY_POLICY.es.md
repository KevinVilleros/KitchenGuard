# Política de Privacidad — CocinaP

**Última actualización:** [DD/MM/AAAA]

---

## 1. Introducción

CocinaP ("nosotros", "la aplicación", "el Servicio") es una aplicación de seguridad inteligente para la cocina que ayuda a detectar fuego, humo y la presencia de personas, y a prevenir situaciones de riesgo durante la cocción.

Esta Política de Privacidad explica qué datos tratamos, cómo los usamos y qué derechos tienes como usuario.

**Nota legal:** Este documento es informativo y de ayuda. No constituye asesoramiento legal. Si tu uso de la aplicación implica obligaciones específicas en tu país (por ejemplo, normativa de videovigilancia o protección de datos como el GDPR en la Unión Europea), te recomendamos consultar con un profesional del derecho.

**Editor de la aplicación:**
- Nombre / Razón social: [Nombre legal de la empresa o persona]
- Correo de contacto: [correo electrónico]
- Dirección: [dirección postal]
- Sitio web: [URL del sitio web]

---

## 2. Principio fundamental: procesamiento local en tu dispositivo

El diseño de CocinaP prioriza tu privacidad. **Las imágenes de las cámaras se procesan directamente en tu dispositivo** (en el teléfono móvil o en el ordenador donde está instalado el sistema).

**No enviamos, almacenamos ni transmitimos a nuestros servidores** las imágenes, clips, videos ni cualquier dato derivado de la detección (como la presencia de personas). Salvo que se indique lo contrario en esta política, todo el análisis de video es local.

Puedes consultar esta implementación técnica en el manual y la arquitectura del proyecto (ver `docs/ARCHITECTURE.md`).

---

## 3. Qué datos y permisos utiliza la aplicación

La aplicación puede solicitar los siguientes permisos y tratar los siguientes datos, únicamente para las finalidades descritas:

### 3.1 Permisos de cámara
- **Finalidad:** capturar el video en vivo de la cocina para analizar la presencia de focos de riesgo y de personas.
- **Nota:** la grabación es local. Las imágenes analizadas no se suben a servidores externos salvo que tú configures servicios de sincronización o notificaciones que lo requieran (ver apartado 4).

### 3.2 Permisos de almacenamiento
- **Finalidad:** guardar la configuración de la aplicación (preferencias, URLs de cámaras, ajustes de detección) de manera local en tu dispositivo.

### 3.3 Permisos de notificaciones
- **Finalidad:** mostrarte alertas locales (sonido y vibración) cuando la aplicación detecta una situación de riesgo, como una cocina desatendida.
- Estas notificaciones se generan y se muestran en el propio dispositivo.

### 3.4 Datos de configuración
- Las preferencias que introduces (p. ej., duración del monitoreo, tiempo de alerta, confianza de detección, configuración de la cámara IP) se guardan **localmente** en tu dispositivo.

### 3.5 Uso de la cámara de terceros (cámaras IP)
- La aplicación puede conectarse a una cámara de seguridad de tu propiedad (cámara IP) a través de la URL que tú mismo configuras. En ese caso, la aplicación **solo accede al stream de video** de dicha cámara para analizarlo localmente. La URL y credenciales que introduzcas se guardan localmente en tu dispositivo.
- **Responsabilidad del usuario:** eres responsable de tener autorización para conectarte a esas cámaras y de cumplir con las leyes de privacidad y videovigilancia aplicables en tu jurisdicción (p. ej., informar a las personas que puedan ser captadas, y no instalar las cámaras en zonas donde la expectativa de privacidad sea alta, como baños o dormitorios).

---

## 4. Detección de personas e imágenes

La aplicación usa modelos de inteligencia artificial y visión por computadora (p. ej., un modelo TFLite de detección de personas) para determinar si hay una persona presente en el campo de visión de la cámara, con el objetivo de avisarte si la cocina queda desatendida.

- **Procesamiento local:** el modelo se ejecuta en el dispositivo. No se almacena ni se transmite el registro de momentos en que se detecta o no una persona, salvo el historial de alertas local.
- **No se crean perfiles:** no usamos la detección para crear perfiles de comportamiento, identificación biométrica ni seguimiento de individuos.
- **Historial de alertas:** la aplicación mantiene un historial limitado de alertas, almacenado localmente, para informarte de los eventos de riesgo.

---

## 5. Compartir datos con terceros

**No vendemos ni alquilamos** tus datos personales.

La aplicación no transmite tu configuración ni las imágenes analizadas a servidores de CocinaP **mientras no configures funciones que requieran conectividad explícita** (por ejemplo, la conexión al servidor/compañero CocinaP que tú mismo instalas y controlas).

### Sobre las notificaciones push (información adicional)
En el caso de que, en el futuro, se habiliten notificaciones push remotas (p. ej., a través de un proveedor de mensajería como Firebase Cloud Messaging), el único dato técnico necesario para el envío sería el identificador del dispositivo, con la única finalidad de entregarte la notificación. No utilizaríamos estos mecanismos para analizar ni revender tus datos. Cualquier activación de estas funciones será informada en esta política.

---

## 6. Retención de datos

- Los datos de configuración se conservan en tu dispositivo hasta que los borres o desinstales la aplicación.
- Puedes eliminar en cualquier momento el historial de alertas desde la configuración de la aplicación.
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

## 10. Cambios en esta política

Podemos actualizar esta Política de Privacidad para reflejar cambios en la aplicación o en la normativa. Cuando lo hagamos, actualizaremos la fecha de "última actualización" al inicio del documento y, cuando sea relevante, lo notificaremos dentro de la propia aplicación.

---

## 11. Contacto

Si tienes preguntas sobre esta Política de Privacidad, el tratamiento de tus datos o el cumplimiento normativo, puedes contactarnos en:

- **Correo electrónico:** [correo electrónico]
- **Dirección:** [dirección postal]
- **Asunto sugerido:** "Privacidad / Protección de datos"

---

*CocinaP — seguridad inteligente para tu cocina.*