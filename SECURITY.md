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
- El proyecto no depende actualmente de Firebase Cloud Messaging; las notificaciones son locales
- Las preferencias no sensibles se almacenan con SharedPreferences en el dispositivo
- La API key se almacena en Keystore/EncryptedSharedPreferences en Android y en Keychain en iOS
- Las claves heredadas se migran una vez desde SharedPreferences y luego se eliminan
- No se recopilan datos personales ni se ofrecen servicios configurados de telemetria

### Dependencias

- Las dependencias se gestionan mediante `pubspec.yaml` y `requirements.txt`
- Las actualizaciones deben revisarse antes de publicar releases
- El modelo YOLO11n se obtiene de Ultralytics cuando se utiliza el backend opcional
- Firebase Cloud Messaging no forma parte actualmente de la app movil

---

## Buenas Practicas

- Mantener Windows y el antivirus actualizados
- Revisar periodicamente los logs en `%APPDATA%\CocinaP\logs\`
- No ejecutar el servidor como administrador sin necesidad
- Usar firewall de Windows para limitar acceso al puerto 8080
- Actualizar CocinaP cuando haya nuevas versiones disponibles
