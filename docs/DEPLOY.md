# Guía de Despliegue

## Instalación en PC del Cliente

### Requisitos Mínimos
- Windows 10/11 64-bit
- CPU x64 con AVX2 (Intel Haswell 2013+ / AMD Ryzen)
- 4 GB RAM (8 GB recomendado)
- 2 GB espacio libre en disco
- Cámara USB o integrada compatible con UVC

### Pasos

1. **Ejecutar instalador**
   - Hacer doble clic en `CocinaP_Setup_v1.0.1.exe`
   - Permitir la instalación (requiere permisos de administrador)
   - Aceptar la ubicación por defecto (`C:\Program Files\CocinaP`)
   - Opcional: marcar "Inicio automático con Windows"

2. **Configurar Firewall**
   Para que la app móvil se conecte desde la red WiFi, agregar regla de firewall:
   ```powershell
   # Ejecutar PowerShell como Administrador:
   netsh advfirewall firewall add rule name="CocinaP Web Server" dir=in action=allow program="C:\Program Files\CocinaP\CocinaP.exe" localport=8080 protocol=tcp enable=yes
   ```

3. **Iniciar CocinaP**
   - Desde el acceso directo del escritorio o menú inicio
   - La ventana principal se abre automáticamente
   - El servidor web se inicia en segundo plano (puerto 8080)

4. **Verificar funcionamiento**
   - Abrir navegador en la PC: `http://127.0.0.1:8080/api/info`
   - Debería responder con JSON de estado
   - La GUI muestra la cámara en vivo (si hay cámara conectada)

### Configuración Inicial

1. **Ajustar zona de estufa**
   - Ir a la pestaña "Config"
   - Arrastrar el rectángulo verde para cubrir la zona de la estufa
   - Guardar

2. **Ajustar sensibilidad** (opcional)
   - En "Config", ajustar parámetros como:
     - `YOLO_CONFIDENCE`: 0.4 (menor = más sensible)
     - `FIRE_COVERAGE_LOW/MEDIUM/HIGH/CRITICAL`: umbrales de cobertura
     - `RISK_COOLDOWN`: segundos entre alertas

---

## App Móvil

### Instalación

1. Descargar el APK desde el sitio de distribución
2. En Android: Ajustes → Seguridad → Permitir instalación de orígenes desconocidos
3. Abrir el APK e instalar
4. Abrir la app "CocinaP"

### Conexión

1. **Auto-descubrimiento (recomendado)**
   - La PC y el móvil deben estar en la **misma red WiFi**
   - En la app, tocar "Buscar en la red"
   - Esperar ~5 segundos a que aparezca la PC
   - Tocar el resultado para conectar

2. **Conexión manual**
   - En la PC, verificar la IP local (ej: `192.168.1.63`)
   - En la app, tocar "Conectar manualmente"
   - Ingresar: `http://192.168.1.63:8080`
   - Tocar "Conectar"

### Solución de Problemas

| Problema | Causa posible | Solución |
|---|---|---|
| "No se encontró servidor" | Firewall bloquea mDNS | Agregar regla firewall (ver arriba) |
| | Router no permite multicast | Usar conexión manual con IP |
| "Error de conexión" | Firewall bloquea puerto 8080 | Agregar regla firewall |
| | El servidor no está corriendo | Verificar que CocinaP esté abierto en la PC |
| | WiFi en diferente subred | Conectar a la misma red WiFi |
| El video no carga | Stream MJPEG bloqueado | Verificar puerto 8080 en firewall |
| | Cámara no disponible en PC | Conectar cámara a la PC |
| Notificaciones push no llegan | FCM no configurado | Firestore: agregar google-services.json |

---

## Notas de Producción

### Rendimiento
- YOLO11n a imgsz=320 procesa ~15-20 FPS en CPU moderna
- Frame downscaled al 25% para YOLO (calidad suficiente para detección)
- Stream MJPEG limitado a ~15 FPS calidad 65 para ancho de banda WiFi
- La app móvil hace polling de status cada 2 segundos

### Seguridad
- El servidor web no tiene autenticación (diseñado para LAN confiable)
- No exponer el puerto 8080 a Internet directo
- Para acceso remoto: usar VPN (WireGuard/OpenVPN) en vez de abrir puertos

### Actualizaciones
- Reemplazar el instalador viejo por el nuevo
- La configuración se preserva en `%APPDATA%\CocinaP\`
- Los logs de crash están en `%APPDATA%\CocinaP\logs\crash.log`
