# ADR 0002 — Eliminar Firebase/FCM del cliente móvil

## Estado
Aceptada

## Contexto

La versión inicial usaba Firebase Cloud Messaging (FCM) para notificaciones push
del backend al teléfono. Esto obligaba a incluir `google-services.json`,
configurar un proyecto Firebase y añadía dependencias que complicaban la
compilación (especialmente sin acceso a la consola de Firebase).

## Decisión

**Eliminar Firebase/FCM del cliente móvil.** Las notificaciones pasan a ser
**locales** (`flutter_local_notifications`) generadas por la propia app.

## Consecuencias

**Positivas**
- La app compila sin `google-services.json`.
- Menos dependencias y configuración.
- El modo independiente ya no depende de servicios externos.

**Negativas**
- No hay push remoto desde el PC al teléfono si la app está cerrada.
- En iOS las notificaciones solo funcionan con la app abierta.

**Neutrales**
- El backend conserva código FCM opcional (`ENABLE_FCM`), desactivado por
  defecto para el flujo móvil.
