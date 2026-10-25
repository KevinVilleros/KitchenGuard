# ADR 0003 — Detección on-device con TFLite

## Estado
Aceptada

## Contexto

El modo independiente debe detectar si hay personas en la cocina sin depender de
un PC ni de la nube, por privacidad y disponibilidad.

## Decisión

Ejecutar la inferencia **en el dispositivo** con **TensorFlow Lite**
(`tflite_flutter`) usando el modelo **SSD MobileNet V2 (COCO)** incluido en
`assets/models/ssd_mobilenet_v2_coco.tflite`. Entrada `1x300x300x3` (uint8),
hasta 20 detecciones; solo se usa la clase "persona".

Solo se detectan **personas** en el móvil. Fuego y humo requieren el backend del
PC.

## Consecuencias

**Positivas**
- Privacidad total: ningún frame sale del dispositivo.
- Funciona sin red.
- Bajo consumo y latencia aceptable en móviles modernos.

**Negativas**
- El modelo COCO no cubre fuego/humo.
- Menor precisión que modelos más pesados.

**Neutrales**
- La lógica de alerta (ausencia de persona) vive en `StandaloneProvider`.
