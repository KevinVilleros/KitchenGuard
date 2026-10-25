# Soporte de plataformas

Este documento define qué significa que CocinaP esté soportada en Android, iOS
y Windows para el backend opcional. Separa implementación, compilación y
validación real en dispositivos.

## Matriz de soporte

| Componente | Plataforma | Requisito | Estado verificable |
|---|---|---:|---|
| App móvil | Android | Android 8.0+ / API 26+ | Código, permisos y build APK/AAB preparados |
| App móvil | iOS | iOS 17.0+ | Código y build de CI preparados; requiere validación física |
| Detección local | Android | Cámara disponible | Modelo TFLite integrado; probar con dispositivos compatibles |
| Detección local | iPhone | Cámara disponible | Modelo y plugin ML Kit integrados; probar en iPhone real |
| Backend opcional | Windows | Windows 10/11, Python 3.10+ | Empaquetado y CI Python disponibles |
| Modo conectado | Android/iOS | Red local compartida | Requiere mDNS, QR o URL manual en ambas plataformas |

## Android

La configuración release se encuentra en `cocinap_mobile/android/app/build.gradle.kts`.
El manifiesto declara Internet, cámara, servicio en primer plano, notificaciones
y reinicio del dispositivo. Antes de publicar una release:

1. Ejecutar `flutter analyze` y `flutter test`.
2. Compilar `flutter build apk --release` y `flutter build appbundle --release`.
3. Instalar el APK en un dispositivo físico limpio.
4. Validar cámara, permisos, alarma, segundo plano, red local y rotación.
5. Registrar el modelo de Android, versión de Android y resultado en la matriz de QA.

## iOS / iPhone

La compilación local requiere macOS con Xcode. Desde Windows, el workflow
`.github/workflows/ios.yml` puede generar un `.ipa` sin firmar mediante GitHub
Actions. Antes de publicar una release:

1. Ejecutar el workflow manualmente o mediante cambios en `cocinap_mobile/**`.
2. Confirmar que el job termina sin errores y descargar `CocinaP-iOS`.
3. Instalar el IPA con Sideloadly o un perfil de distribución válido.
4. Validar cámara, red local, notificaciones, servicio en segundo plano y cambios
de orientación en al menos un iPhone físico.
5. Registrar modelo de dispositivo, versión de iOS y resultado en la matriz de QA.

Un IPA sin firmar no representa una distribución de producción. Una cuenta
Apple gratuita puede imponer una caducidad aproximada de siete días.

## Matriz de pruebas mínimas

| Prueba | Android | iPhone | Criterio |
|---|---:|---:|---|
| Instalación desde artefacto release | Requerida | Requerida | Arranca sin crash ni pérdida de datos |
| Permiso de cámara | Requerida | Requerida | Se explica antes de solicitarlo y puede denegarse |
| Permiso de red local/notificaciones | Si aplica | Requerida | La función muestra el motivo y conserva un estado válido |
| Detección en cámara móvil | Requerida | Requerida | Detecta/no detecta personas según pruebas documentadas |
| Cámara IP/MJPEG | Recomendada | Recomendada | Reproduce el stream sin bloqueos |
| Conexión al backend | Recomendada | Recomendada | QR, mDNS y conexión manual funcionan |
| Rotación de pantalla | Requerida | Requerida | La interfaz no pierde estado ni corta controles |
| Suspensión/resumen | Requerida | Requerida | Retoma sin errores o detiene de forma controlada |

## Criterio de aprobación

Una plataforma puede declararse lista para una release cuando el build es
reproducible, todas las pruebas críticas están aprobadas, se registra el entorno
de validación y los errores conocidos tienen un plan de corrección.
