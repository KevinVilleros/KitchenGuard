# Soporte de plataformas

Este documento define qué significa que CocinaP esté soportada en Android, iOS
y Windows. Separa implementación, compilación y validación real en dispositivos.

## Matriz de soporte

| Componente | Plataforma | Requisito | Estado verificable |
|---|---|---:|---|
| App móvil | Android | Android 8.0+ / API 26+ | Código, permisos y build APK/AAB preparados |
| App móvil | iOS | iOS 17.0+ | Código y build de CI preparados; requiere validación física |
| Detección local | Android | Cámara disponible | ML Kit integrado; servicio de cámara en primer plano implementado; validar en dispositivos físicos |
| Detección local | iPhone | Cámara disponible | ML Kit integrado; probar en iPhone real |
| Detección local | Windows | Cámara disponible | MoveNet/ONNX integrado; build y cámara física pendientes |
| Cámara IP | Android | Cámara ONVIF/RTSP o HTTP/MJPEG en LAN | ONVIF y RTSP implementados; matriz física pendiente |
| Cámara IP | iOS | Cámara ONVIF/RTSP o HTTP/MJPEG en LAN | RTSP/MJPEG implementado; descubrimiento multicast requiere QA en iPhone |
| App de escritorio | Windows | Windows 10/11, modo desarrollador y carga C++ de Visual Studio 2022 | Target Flutter implementado; build y validación física pendientes |
| Cámara remota | Windows + Android/iOS | Tailscale en ambos dispositivos | API autenticada implementada; validación de extremo a extremo pendiente |

## Android

La configuración release se encuentra en `cocinap_mobile/android/app/build.gradle.kts`.
El manifiesto declara Internet, cámara, servicio en primer plano, notificaciones
y reinicio del dispositivo. Antes de publicar una release:

**Bloqueo actual:** la configuración `release` todavía usa la firma `debug`.
No distribuyas APK/AAB construidos con esa firma; configura y valida una clave
de firma de producción fuera del repositorio.

1. Ejecutar `flutter analyze` y `flutter test`.
2. Compilar `flutter build apk --release` y `flutter build appbundle --release`.
3. Instalar el APK en un dispositivo físico limpio.
4. Validar cámara, permisos, alarma, servicio de cámara en segundo plano, red local y rotación. El monitoreo en segundo plano actualmente solo cubre la cámara del teléfono; las cámaras IP requieren que CocinaP permanezca abierta.
5. Registrar el modelo de Android, versión de Android y resultado en la matriz de QA.

## iOS / iPhone

La compilación local requiere macOS con Xcode. Desde Windows, el workflow
`.github/workflows/ios.yml` puede generar un `.ipa` sin firmar mediante GitHub
Actions. Antes de publicar una release:

1. Ejecutar el workflow manualmente o mediante cambios en `cocinap_mobile/**`.
2. Confirmar que el job termina sin errores y descargar `CocinaP-iOS`.
3. Instalar el IPA con Sideloadly o un perfil de distribución válido.
4. Validar cámara, red local, notificaciones y cambios
de orientación en al menos un iPhone físico.
5. Registrar modelo de dispositivo, versión de iOS y resultado en la matriz de QA.

Un IPA sin firmar no representa una distribución de producción. Una cuenta
Apple gratuita puede imponer una caducidad aproximada de siete días.
En iPhone, la cámara y la detección no continúan cuando CocinaP pasa a segundo
plano. Para alertas continuas con la app cerrada, el análisis debe ejecutarse
en un host activo y enviar notificaciones push; esa integración aún no está
implementada.

## Windows

Activa el modo de desarrollador de Windows e instala Visual Studio 2022 con la
carga **Desarrollo para el escritorio con C++**. Después ejecuta:

```powershell
cd cocinap_mobile
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

La app Windows usa `camera_windows` para capturar instantáneas de webcam (~1
fotograma por segundo) y MoveNet Lightning mediante ONNX Runtime. La frecuencia
de cámaras IP depende de la fuente. Valida ambas fuentes y el acceso Tailscale
en hardware Windows antes de declarar el target listo para release.

## Matriz de pruebas mínimas

| Prueba | Android | iPhone | Windows | Criterio |
|---|---:|---:|---:|---|
| Instalación desde artefacto release | Requerida | Requerida | Requerida | Arranca sin crash ni pérdida de datos |
| Permiso de cámara | Requerida | Requerida | Requerida | Se explica antes de solicitarlo y puede denegarse |
| Detección en cámara | Requerida | Requerida | Requerida | Detecta/no detecta personas según pruebas documentadas |
| Cámara IP/RTSP/MJPEG | Requerida | Requerida | Requerida | Reproduce el stream sin bloqueos |
| Descubrimiento ONVIF | Requerida para cámaras ONVIF | Requerida para cámaras ONVIF | Requerida para cámaras ONVIF | Cámara en la misma LAN; validar multicast/permiso local en iPhone |
| Stream remoto Tailscale | Requerida | Requerida | Requerida | Video autenticado fuera de LAN; sin redirección de puertos |
| Suspensión o PC dormido | Requerida | Requerida | Requerida | Retoma con seguridad o informa cámara no disponible |

## Criterio de aprobación

Una plataforma puede declararse lista para una release cuando el build es
reproducible, todas las pruebas críticas están aprobadas, se registra el entorno
de validación y los errores conocidos tienen un plan de corrección.
