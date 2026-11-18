# ADR 0005 — Retirar el backend de escritorio Python archivado

## Estado
Aceptada; sustituye la decisión anterior de conservar el backend archivado.

## Contexto

La decisión anterior archivó la aplicación de escritorio Python/YOLO en
`yolo/`. El producto ahora requiere una implementación Flutter para móvil y
Windows, con MoveNet en Windows y un stream de cámara autenticado por Tailscale.

## Decisión

Eliminar la implementación Python/YOLO archivada y usar el target Flutter
Windows para el monitoreo de escritorio y el video remoto.

## Consecuencias

**Positivas**
- Una aplicación Flutter y un flujo de detección para móvil y Windows.
- No hace falta mantener un runtime o instalador de escritorio Python separado.

**Negativas**
- Los builds Windows requieren herramientas Flutter desktop y compiladores C++.

**Neutrales**
- Windows usa MoveNet Lightning y no ofrece las funciones anteriores de
  detección de fuego/humo.
