# ADR 0003 — Detección de personas on-device

## Estado
Aceptada

## Contexto

El modo independiente debe detectar si hay personas en la cocina sin depender de
un PC ni de la nube, por privacidad y disponibilidad.

## Decisión

Ejecutar la inferencia localmente con modelos de pose compatibles por
plataforma: Google ML Kit Pose Detection en Android/iOS y MoveNet Lightning
mediante ONNX Runtime en Windows. El modelo Windows se incluye en
`assets/models/movenet_lightning.onnx` y devuelve una pose de 17 puntos.

Solo se detectan **personas**. Los fotogramas no se envían a la nube. La webcam
Windows se captura por instantáneas de aproximadamente un fotograma por segundo.

## Consecuencias

**Positivas**
- Privacidad total: ningún frame sale del dispositivo.
- Funciona sin red.
- Bajo consumo y latencia aceptable en móviles modernos.

**Negativas**
- Windows y móvil utilizan modelos diferentes y pueden producir resultados
  distintos.

**Neutrales**
- La lógica de alerta (ausencia de persona) vive en `StandaloneProvider`.
