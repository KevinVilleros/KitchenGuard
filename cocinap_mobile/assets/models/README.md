# Detección de personas en CocinaP

El modo independiente usa **Google ML Kit Pose Detection** en el dispositivo.
No carga un archivo TFLite desde esta carpeta: ML Kit inicializa su detector de
poses y devuelve puntos del cuerpo que la app usa para estimar la presencia de
una persona.

La misma tecnología recibe frames de la cámara del teléfono y de cámaras IP:

- **Cámara del teléfono:** frames del plugin `camera`.
- **MJPEG y RTSP:** JPEG decodificado del stream de la cámara IP.
- **Android:** las imágenes RGB se convierten a NV21, formato aceptado por ML Kit.
- **iOS:** las imágenes RGB se convierten a BGRA8888, formato aceptado por ML Kit.

La cámara debe mostrar suficientes partes visibles del cuerpo y mantener a la
persona dentro del encuadre. La visión nocturna infrarroja monocromática puede
funcionar, pero la oscuridad, el desenfoque, el bajo contraste, el contraluz o
una vista parcial pueden reducir la confianza y hacer que una pose no se
detecte. Para comprobar el estado, revisa el panel de diagnóstico de la cámara:
el contador de frames procesados debe avanzar y el porcentaje de confianza debe
superar el umbral configurado.
