# CocinaP Mobile — App de monitoreo de cocina

Aplicación móvil Flutter compatible con Android y iOS para el sistema de seguridad CocinaP.

## Estado de plataforma

| Plataforma | Estado |
|---|---|
| Android | Implementada y distribuible como APK/AAB. Requiere pruebas de instalación y permisos por dispositivo y release. |
| iOS / iPhone | Implementada con build de CI y configuración de permisos. Requiere compilación firmada o `.ipa` y validación física en iPhone. |

La compatibilidad de código, un workflow de CI y una configuración de plataforma no reemplazan una matriz de pruebas en dispositivos reales.

## Características

- Monitoreo independiente con la cámara del móvil o una cámara IP.
- Detección de personas on-device con TFLite.
- Alertas locales con sonido y vibración.
- Dashboard MJPEG y alarmas en tiempo real.
- Descubrimiento mDNS, QR y conexión manual.
- Interfaz en español e inglés.

## Compilar Android

```bash
cd cocinap_mobile
flutter pub get
flutter build apk --release
```

## Compilar iOS

```bash
cd cocinap_mobile
flutter build ipa --release
```

Sin Mac, ejecuta el workflow **Mobile Builds CocinaP** desde GitHub Actions, descarga `CocinaP-iOS` e instala el `.ipa` con Sideloadly.

## Documentación

- [Versión principal en inglés](README.md)
- [Documentación general](../docs/README.md)
