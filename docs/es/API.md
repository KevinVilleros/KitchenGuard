# API de cámara remota — CocinaP Windows

La app Windows ofrece una pequeña API HTTP autenticada para el modo de cámara
remota de la app móvil. Usa Tailscale Serve para acceder mediante una dirección
HTTPS privada; no expongas el puerto 8080 a Internet.

- **Dirección local:** `http://127.0.0.1:8080`
- **Dirección remota:** HTTPS de Tailscale Serve terminada en `.ts.net`
- **Autenticación:** cabecera `X-API-Key`

La app Windows genera una clave aleatoria de 32 bytes y la guarda en
almacenamiento seguro. Cópiala desde **Ajustes** de Windows e ingrésala en la
app móvil. No incluyas la clave en una URL ni la compartas fuera de la tailnet
confiable.

## `GET /api/info`

Devuelve la aplicación host y el estado de la cámara.

```http
GET /api/info HTTP/1.1
Host: cocina-pc.example.ts.net
X-API-Key: <64 caracteres hexadecimales>
```

Respuesta correcta (`200`):

```json
{
  "app": "CocinaP",
  "auth_required": true,
  "camera_ok": true
}
```

`camera_ok` solo es `true` si la cámara seleccionada produjo un fotograma
reciente. Una clave ausente o incorrecta devuelve `401 Unauthorized`.

## `GET /api/stream`

Devuelve un stream MJPEG con el tipo de contenido
`multipart/x-mixed-replace; boundary=frame`. Cada parte contiene un fotograma
JPEG. El stream termina si la cámara deja de producir fotogramas recientes o si
el cliente se desconecta.

Una clave ausente o incorrecta devuelve `401 Unauthorized`. Si no hay un
fotograma reciente al iniciar la petición, el servidor devuelve
`503 Service Unavailable`.

La implementación de webcam Windows captura instantáneas a aproximadamente un
fotograma por segundo. La frecuencia de una cámara IP depende de la cámara y su
URL.

## Peticiones y cabeceras compatibles

Solo se admite `GET`. Las rutas desconocidas devuelven `404`; otros métodos
HTTP devuelven `405`. Las respuestas incluyen `Cache-Control: no-store` y
`X-Content-Type-Options: nosniff`.

El acceso remoto está diseñado para Tailscale Serve. Mantén ambos dispositivos
en la misma tailnet privada y no uses Tailscale Funnel ni redirección de puertos
del router.
