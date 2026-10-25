# ADR 0004 — Gestión de estado con Provider

## Estado
Aceptada

## Contexto

La app móvil necesita gestionar varios dominios de estado: conexión al PC,
alarmas, monitoreo independiente y tour de interfaz.

## Decisión

Usar el paquete **`provider`** (`ChangeNotifier`) como solución de gestión de
estado, con **un provider por dominio**:

- `ServerProvider` — conexión al PC y descubrimiento.
- `AlarmsProvider` — alarmas del servidor.
- `StandaloneProvider` — monitoreo independiente.
- `TourController` — tour de la interfaz.

## Consecuencias

**Positivas**
- API sencilla y ampliamente adoptada.
- Bajo acoplamiento: cada dominio es independiente.
- Fácil de testear de forma aislada.

**Negativas**
- Sin gestión declarativa avanzada (a diferencia de Riverpod/Bloc).

**Neutrales**
- Se puede migrar a Riverpod en el futuro si la complejidad crece.
