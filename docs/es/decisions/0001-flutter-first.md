# ADR 0001 — Flutter como tecnología principal

## Estado
Aceptada

## Contexto

El proyecto surgió como un sistema de escritorio en Python (PySide6 + YOLO) para
detectar fuego, humo y cocina desatendida en un PC con cámara. Sin embargo, el
usuario final (hogar) necesita una alerta cuando no está frente al PC, y el
despliegue de un escritorio en cada cocina no escala.

## Decisión

Adoptar una **app móvil Flutter** (Android e iOS) como tecnología principal del
producto, capaz de operar de forma completamente independiente con la cámara del
teléfono y detección on-device. El escritorio Python se conservó inicialmente
como backend opcional y luego se retiró; ver ADR 0005.

## Consecuencias

**Positivas**
- Un único código para Android e iOS.
- No requiere PC ni Internet en el modo principal.
- Mejor cobertura de casos de uso domésticos.

**Negativas**
- Se necesita aprender/afinar el ecosistema Flutter y Dart.
- La compilación de iOS requiere infraestructura adicional (ver ADR 0006).
