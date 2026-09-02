# Modelo de detección de personas (TFLite)

Para que el **modo independiente** (monitoreo con la cámara del móvil **o una
cámara IP**) funcione, coloca aquí un modelo MobileNetV2 SSD-COCO convertido a
TFLite con el nombre:

```
assets/models/ssd_mobilenet_v2_coco.tflite
```

## Cómo obtener el modelo

El modelo ya incluido es **SSD MobileNet V2 COCO cuantizado** con
**entrada uint8 (300x300x3)** y **20 detecciones máximas** de salida
(pipeline `TFLite_Detection_PostProcess`):

- Origen: `coral/ssd_mobilenet_v2_coco_quant_postprocess.tflite`
  (verificado por SHA256).
- Entrada: `[1, 300, 300, 3]` `uint8` (valores RGB [0,255] directos).
- Salidas: `[1, 20, 4]` boxes, `[1, 20]` classes, `[1, 20]` scores, `[1]` detections.
- Clases: COCO 90 clases. La clase **1 = person**.

Alternativa compatible (mismo esquema de salida con 10 detecciones):
`coco_ssd_mobilenet_v1_1.0_quant_2018_06_29/detect.tflite` de Google.

## Referencia en código

`lib/services/person_detector.dart` carga el modelo desde
`assets/models/ssd_mobilenet_v2_coco.tflite`.

El detector:
- Redimensiona cada frame a 300x300 (RGB, entrada uint8 cuantizada [0,255])
- Ejecuta detección y filtra la clase **1 (person)** con confianza configurable
- Devuelve el número de personas presentes (hasta 20 detecciones)

El mismo detector se usa tanto para la **cámara del móvil** (frames YUV/YCbCr →
imagen en escala de grises) como para las **cámaras IP** (streams HTTP/MJPEG →
`detectFromJpeg`, que decodifica cada JPEG con `package:image`).

## Conexión de cámaras IP (hogar / seguridad)

En **Ajustes → Fuente de cámara** puedes elegir la cámara del móvil o una cámara
IP, e ingresar su URL **HTTP/MJPEG**. El stream se consume con `MjpegService` y
cada JPEG se envía de inmediato a `detectFromJpeg`.

Formatos soportados:
- **HTTP/MJPEG**: compatible de forma nativa (ej. `http://usuario:pass@192.168.1.100/stream`)
- **RTSP (H.264)**: *no consumible aún* en el móvil; requiere un componente
  adicional de decodificación (pendiente).

Consulta la guía completa dentro de la app en **Ajustes → Manual, guía y términos**.

## Nota sobre iOS/Android

- **iOS:** requiere autorización de cámara (`NSCameraUsageDescription` ya agregado)
- **Android:** requiere permisos de cámara (`CAMERA`) y `POST_NOTIFICATIONS`

## Tiempo peligroso estimado

El modo independiente considera que dejar la cocina sin atender es **riesgoso** a
partir del valor configurable "Tiempo peligroso sin atender (min)" (por defecto 5 min).
Cuando no se detecta persona y ese tiempo se supera, la app muestra una alerta y
sugiere revisar la cocina de inmediato.
