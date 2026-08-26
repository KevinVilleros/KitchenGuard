# Política de Seguridad

## Versiones Soportadas

| Versión | Soportada |
|---|---|
| 1.0.x | Sí |

## Reportar Vulnerabilidades

Si encontrás una vulnerabilidad de seguridad en CocinaP:

1. **No la reportes en GitHub Issues**
2. Enviá un email a los mantenedores del proyecto
3. Incluí una descripción detallada del problema y pasos para reproducirlo
4. Si es posible, incluí una prueba de concepto

### Proceso

- Recibimos el reporte y lo confirmamos dentro de 48 horas
- Evaluamos el impacto y priorizamos la solución
- Desarrollamos y probamos el fix
- Publicamos un release con el parche de seguridad
- Notificamos al reportero cuando el fix está disponible

## Buenas Prácticas

- El servidor web está diseñado para uso exclusivo en **red LAN confiable**
- No exponer el puerto 8080 a Internet
- Usar VPN (WireGuard/OpenVPN) para acceso remoto
- Mantener Windows y el antivirus actualizados
- Revisar periódicamente los logs en `%APPDATA%\CocinaP\logs\`
