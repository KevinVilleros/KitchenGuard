# Politica de Seguridad

## Versiones Soportadas

| Version | Soportada |
|---|---|
| 1.0.x | Si |

---

## Reportar Vulnerabilidades

Si encontraste una vulnerabilidad de seguridad en CocinaP:

1. **No la reportes en GitHub Issues** (es publico)
2. Envia un email a **kevinvilleros77@gmail.com** con:
   - Descripcion detallada del problema
   - Pasos para reproducirlo
   - Prueba de concepto si es posible
   - Version afectada
3. Recibiras confirmacion dentro de **48 horas**

### Proceso de Resolucion

| Fase | Tiempo estimado |
|---|---|
| Confirmacion del reporte | 48 horas |
| Evaluacion de impacto | 1 semana |
| Desarrollo del fix | 1-2 semanas |
| Testing y release | 1 semana |
| Notificacion al reportero | Al publicar el fix |

---

## Diseno de Seguridad

### Red

- El servidor web esta disenado para uso exclusivo en **red LAN confiable**
- **No exponer** el puerto 8080 a Internet
- Usar VPN (WireGuard/OpenVPN) para acceso remoto
- Auto-descubrimiento mDNS solo funciona en la subred local

### Datos

- La configuracion se almacena en `%APPDATA%\CocinaP/config.json`
- Los logs de eventos estan en `%APPDATA%\CocinaP\logs\`
- Los tokens FCM se almacenan localmente (encriptados por Android/iOS)
- No se recopilan datos personales

### Dependencias

- Todas las dependencias se instalan via pip/pub con versiones fijadas
- El modelo YOLO11n se descarga de Ultralytics (fuente verificada)
- Firebase Admin SDK solo se usa si FCM esta habilitado

---

## Buenas Practicas

- Mantener Windows y el antivirus actualizados
- Revisar periodicamente los logs en `%APPDATA%\CocinaP\logs\`
- No ejecutar el servidor como administrador sin necesidad
- Usar firewall de Windows para limitar acceso al puerto 8080
- Actualizar CocinaP cuando haya nuevas versiones disponibles
