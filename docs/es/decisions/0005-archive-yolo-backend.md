# ADR 0005 — Archivar el backend YOLO en `yolo/`

## Estado
Aceptada

## Contexto

Tras adoptar la app Flutter como tecnología principal (ADR 0001), el backend
Python ocupaba la raíz del repositorio (`cocinap/`, `tests/`, `installer/`,
`scripts/`, `main.py`, builds, `models/`, docs), mezclándose con el producto
activo y dificultando la navegación.

## Decisión

Reorganizar el backend Python/YOLO bajo la carpeta **`yolo/`**, preservando el
historial de git (usando `git mv` para que git lo detecte como renombrado), y
reescribir el `README.md` raíz con enfoque Flutter-first.

## Consecuencias

**Positivas**
- Raíz limpia y centrada en la app móvil.
- Separación clara entre producto activo y backend archivado.
- El CI de Python apunta a `working-directory: yolo`.

**Negativas**
- Hay que actualizar rutas en scripts y documentación.

**Neutrales**
- El backend sigue siendo funcional y opcional.
