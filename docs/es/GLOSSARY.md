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
- **Modo de cámara remota:** el teléfono recibe el stream autenticado de Windows
  mediante Tailscale.
- **Modo independiente (standalone):** la app monitorea una cámara local o IP.

## P

- **Provider:** patrón de gestión de estado de Flutter usado en la app.
- **MoveNet Lightning:** modelo de pose de una persona usado en Windows.
- **ONNX Runtime:** runtime de inferencia del modelo en Windows.

## R

- **Rate limiting:** límite de peticiones por unidad de tiempo.
- **ROI (Region of Interest):** zona de interés del encuadre (p. ej. la estufa).
- **RTSP:** protocolo de streaming de cámaras IP compatible con el modo
  independiente móvil.

## S

- **SEMVER:** versionado semántico `MAJOR.MINOR.PATCH`.
- **Sideloadly:** herramienta para instalar `.ipa` en iPhone sin App Store.
- **STOVE_ZONE:** configuración heredada de zona de estufa.

## T

- **TFLite (TensorFlow Lite):** runtime de modelos; no se usa en la detección
  actual de personas.
- **Temporizador de monitoreo:** plazo durante el cual se vigila la cocina.

---

## Convenciones de nombres del proyecto

| Término en el código | Significado |
|---|---|
| `StandaloneProvider` | Estado del modo independiente |
| `ServerProvider` | Estado de conexión heredada al PC |
| `PersonDetector` | Detector de poses local específico de la plataforma |
| `RemoteCameraServer` | Host autenticado de cámara Windows (puerto 8080) |
