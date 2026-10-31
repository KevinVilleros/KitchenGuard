# Roadmap — CocinaP

Estado actual y funcionalidades planificadas. Es un documento vivo.

---

## Estado actual (v1.0.2-pre)

### Completado

- App móvil Flutter (Android + iOS) con 5 pestañas.
- Modo independiente: cámara del móvil o cámara IP.
- Descubrimiento ONVIF en la red local; reproducción RTSP y HTTP/MJPEG.
- Detección de personas **on-device** con TFLite (SSD MobileNet V2 / COCO).
- Temporizador de monitoreo con pausa/reanudar/detener.
- Alertas locales (sonido + vibración) por cocina desatendida.
- Notificaciones locales en segundo plano (Android).
- Conexión al PC: mDNS, QR y manual.
- Stream MJPEG del PC y alarmas por SSE.
- Backend Python/YOLO con detección de fuego/humo (archivado en `yolo/`).
- Seguridad del backend: API key, rate limiting, auditoría.
- Interfaz bilingüe (ES/EN).
- Onboarding, guía de cámara y tour guiado de la interfaz.
- CI: build de iOS en la nube y CI de Python.

---

## Próximas versiones

### Bloqueos antes de publicar v1.0.2

- [ ] Probar ONVIF, RTSP y MJPEG en una matriz documentada de modelos/cámaras y
  routers; el modelo V380 Pro / AIT36106 todavía no está validado.
- [ ] Probar instalación, actualización, permisos, alertas, reconexión y
  segundo plano en Android y iPhone físicos.
- [ ] Configurar firma de producción y verificar APK/AAB e IPA firmados; la
  clave de depuración no es válida para publicar.
- [ ] Revisar licencias de libmpv, FFmpeg/codecs y demás dependencias nativas;
  incorporar avisos y cumplir las obligaciones de redistribución aplicables.
- [ ] Cambiar la firma `debug` configurada en el build release por una clave de
  producción protegida fuera del repositorio.
- [ ] Completar los datos del editor y los campos pendientes de las políticas
  legales; revisar las declaraciones de privacidad y seguridad de las tiendas.
- [ ] Completar revisión legal/comercial y publicar términos, política de
  privacidad, datos de soporte y descripción exacta de las capacidades.

El descubrimiento ONVIF ya está implementado, pero solo encuentra cámaras que
anuncian ONVIF en la red local. No se garantiza compatibilidad por la marca de
la aplicación del fabricante; una IP visible en el router no implica que la
cámara exponga un stream compatible. El móvil y la cámara deben poder
comunicarse directamente en la misma red.

### v1.1 — Experiencia y estabilidad

- [ ] Historial persistente de alertas locales en el móvil.
- [x] Selector de cámara IP con descubrimiento ONVIF y alternativa manual.
- [ ] Modo pantalla siempre activa durante el monitoreo.
- [ ] Tests de widgets ampliados (monitoreo, ajustes, tour).
- [ ] Accesibilidad: tamaños de texto y contraste.

### v1.2 — Inteligencia

- [ ] Detección on-device de fuego/humo (modelo ligero) sin PC.
- [ ] Zona de cocción configurable desde el móvil (ROI en pantalla).
- [ ] Múltiples cámaras simultáneas.

### v1.3 — Integraciones

- [ ] Exportar historial de alarmas (CSV/JSON).
- [ ] Widgets de pantalla de inicio (estado de monitoreo).
- [ ] Soporte para más plataformas de escritorio del backend.

### Backlog

- Localización adicional (más idiomas).
- Modo multiusuario / varios dispositivos.
- Emparejamiento seguro con rotación de API key desde la app.

---

## Cómo proponer una funcionalidad

Abre un issue en
[GitHub Issues](https://github.com/KevinVilleros/KitchenGuard/issues) con:

- Problema o necesidad.
- Solución propuesta.
- Alternativas consideradas.
