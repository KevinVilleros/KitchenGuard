# Glosario — CocinaP

Términos, siglas y conceptos usados en el proyecto.

---

## A

- **ADR (Architecture Decision Record):** registro de una decisión de
  arquitectura con su contexto y consecuencias.
- **API key:** clave secreta que autentica la app móvil ante el backend.
- **APK:** paquete instalable de Android.
- **AAB (Android App Bundle):** formato de publicación para Google Play.

## C

- **COCO:** conjunto de datos de objetos (entre ellos, la clase "persona") que
  usa el modelo del móvil.
- **CORS:** política de acceso entre orígenes para el servidor HTTP.
- **CI/CD:** integración y entrega continuas.

## D

- **Detección on-device:** inferencia ejecutada en el propio dispositivo, sin
  nube.
- **Desatendida (cocina):** situación en la que no hay ninguna persona en la
  zona de cocción mientras cocina.

## E

- **SSE (Server-Sent Events):** canal unidireccional servidor→cliente para
  eventos en tiempo real (alarmas).

## F

- **FCM (Firebase Cloud Messaging):** mensajería push; **eliminada** del cliente
  móvil.
- **Flutter:** framework de UI multiplataforma usado por la app móvil.

## I

- **iOS deployment target:** versión mínima de iOS soportada (17.0).
- **IPA:** paquete instalable de iOS.

## M

- **mDNS (multicast DNS):** descubrimiento de servicios en la red local
  (`_cocinap._tcp.local.`).
- **MJPEG (Motion JPEG):** stream de video compuesto por frames JPEG
  consecutivos.
- **Modo conectado:** la app consume el backend del PC.
- **Modo independiente (standalone):** la app funciona sin PC.

## P

- **Provider:** patrón de gestión de estado de Flutter usado en la app.
- **PySide6:** framework Qt para la GUI de escritorio del backend.

## R

- **Rate limiting:** límite de peticiones por unidad de tiempo.
- **ROI (Region of Interest):** zona de interés del encuadre (p. ej. la estufa).
- **RTSP:** protocolo de streaming de cámaras IP (no soportado directamente en
  el móvil).

## S

- **SEMVER:** versionado semántico `MAJOR.MINOR.PATCH`.
- **Sideloadly:** herramienta para instalar `.ipa` en iPhone sin App Store.
- **SSD MobileNet V2:** arquitectura del modelo de detección on-device.
- **STOVE_ZONE:** zona rectangular de la estufa dentro del encuadre.

## T

- **TFLite (TensorFlow Lite):** runtime de modelos para dispositivos móviles.
- **Temporizador de monitoreo:** plazo durante el cual se vigila la cocina.

## Y

- **YOLO (You Only Look Once):** familia de modelos de detección de objetos usada
  en el backend del PC (`YOLO11n`).

---

## Convenciones de nombres del proyecto

| Término en el código | Significado |
|---|---|
| `StandaloneProvider` | Estado del modo independiente |
| `ServerProvider` | Estado de conexión al PC |
| `PersonDetector` | Detector TFLite de personas |
| `WEB_PORT` | Puerto del servidor del backend (8080) |
| `APP_DATA` | Carpeta de datos del backend (`%APPDATA%\CocinaP`) |
