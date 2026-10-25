# Roadmap — CocinaP

Estado actual y funcionalidades planificadas. Es un documento vivo.

---

## Estado actual (v1.0.x)

### Completado

- App móvil Flutter (Android + iOS) con 5 pestañas.
- Modo independiente: cámara del móvil o cámara IP.
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

### v1.1 — Experiencia y estabilidad

- [ ] Historial persistente de alertas locales en el móvil.
- [ ] Selector de cámara IP con descubrimiento en red local.
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
