# Modelo de detección de personas (TFLite)

Para que el **modo independiente** (monitoreo con la cámara del móvil) funcione,
coloca aquí un modelo MobileNetV2 SSD-COCO convertido a TFLite con el nombre:

```
assets/models/ssd_mobilenet_v2_coco.tflite
```

## Cómo obtener el modelo

**Opción A (recomendada):** Descarga el modelo oficial desde TensorFlow Hub:

- Repos: `SSD MobileNet V2` de TensorFlow Detection Zoo
- Convertido a `.tflite` con `--input_shapes=1,300,300,3`
- Clases: COCO 90 clases. La clase **1 = person**.

**Opción B:** Usa `tf1.lite.TFLiteConverter` sobre el checkpoint de SSD MobileNet V2.

## Referencia en código

`lib/services/person_detector.dart` carga el modelo desde
`assets/models/ssd_mobilenet_v2_coco.tflite`.

El detector:
- Redimensiona cada frame a 300x300 (RGB, normalizado a [0,1])
- Ejecuta detección y filtra la clase **1 (person)** con confianza configurable
- Devuelve el número de personas presentes

## Nota sobre iOS/Android

- **iOS:** requiere autorización de cámara (`NSCameraUsageDescription` ya agregado)
- **Android:** requiere permisos de cámara (`CAMERA`) y `POST_NOTIFICATIONS`

## Tiempo peligroso estimado

El modo independiente considera que dejar la cocina sin atender es **riesgoso** a
partir del valor configurable "Tiempo peligroso sin atender (min)" (por defecto 5 min).
Cuando no se detecta persona y ese tiempo se supera, la app muestra una alerta y
sugiere revisar la cocina de inmediato.
