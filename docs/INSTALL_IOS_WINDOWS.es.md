# Cómo instalar la app CocinaP en tu iPhone SIN una Mac

Esta guía te permite instalar la app CocinaP en tu iPhone desde un PC con
Windows, sin necesidad de tener una Mac.

**Requisitos:**
- Un PC con Windows
- Tu iPhone con cable USB (Lightning / USB-C)
- Un Apple ID (gratis, se crea en https://appleid.apple.com)
- Internet

> **Importante:** con Apple ID gratuito la app **expira a los 7 días** y debes
> repetir los pasos para reinstalarla (límite de 3 apps firmadas a la vez).

---

## Paso 1 — Compilar la app en la nube (GitHub Actions)

No podemos compilar iOS en Windows, pero GitHub nos presta un Mac en internet
gratis para hacerlo.

1. Entra en tu repositorio de GitHub:
   `https://github.com/KevinVilleros/KitchenGuard`
2. Ve a la pestaña **Actions**.
3. En el menú lateral elige el workflow **"Build iOS IPA"**.
4. Pulsa el botón **"Run workflow"** (usa la rama `main`) y **"Run workflow"** de nuevo.
   (También se ejecuta solo cada vez que haces push de la app.)
5. Espera a que el job quede **en verde** (unos 10-20 minutos la primera vez).
6. Pincha sobre el job terminado y baja hasta la sección **"Artifacts"**.
7. Descarga el archivo **`cocinap-ios`** → dentro está **`cocinap_mobile.ipa`**.
8. Descomprímelo en una carpeta (p. ej. `C:\Users\tu\Desktop\cocinap`).

---

## Paso 2 — Instalar Sideloadly en Windows

1. Descarga Sideloadly desde: <https://sideloadly.io>
2. Ejecuta el instalador (sigue los pasos por defecto).
3. Abre Sideloadly.

---

## Paso 3 — Preparar el iPhone

1. Conecta el iPhone al PC con el cable USB.
2. En el iPhone acepta el mensaje **"Confiar en este equipo"** (escribe tu código
   de acceso cuando lo pida).
3. Ten a mano tu **Apple ID** y contraseña (o crea uno en
   https://appleid.apple.com si no tienes).

---

## Paso 4 — Firmar e instalar con Sideloadly

1. En Sideloadly, selecciona tu iPhone en el menú superior si hay varios
   dispositivos (normalmente se detecta solo).
2. Arrastra el archivo **`cocinap_mobile.ipa`** a la ventana de Sideloadly.
3. Escribe tu **Apple ID** y **contraseña** en los campos *Apple ID* y *Password*.
   (Solo se usa para firmar la app en ese momento; Sideloadly puede guardarla
   en tu PC de forma opcional.)
4. Pulsa **"Start"**.
5. Espera a que aparezca el mensaje de éxito (puede tardar un par de minutos).
6. Busca el icono de **CocinaP** en la pantalla de inicio del iPhone.

---

## Paso 5 — Confiar en la app (primera vez)

Al abrir CocinaP por primera vez puede pedir verificación:

1. En el iPhone ve a **Ajustes > General > VPN y gestión de dispositivos**.
2. Toca el perfil de desarrollador (tu Apple ID).
3. Pulsa **"Confiar"**.
4. Abre la app de nuevo.

---

## Después de los 7 días (expiración)

Cuando la app deje de abrirse (vence la firma):

1. Repite el **Paso 1** (descarga el último `.ipa` de Actions).
2. Repite el **Paso 4** con Sideloadly (solo firmar y instalar).
3. La app se actualiza y vuelve a funcionar otros 7 días.

> Consejo: si quieres evitar re-instalar cada 7 días, la vía definitiva es una
> **cuenta de desarrollador de Apple** (USD 99/año) y publicar en la App Store.
> Es lo recomendado si sales al mercado comercialmente.

---

## Limitaciones conocidas de la app en iOS

- En iPhone las **alarmas suenan mientras la app está abierta**. En segundo
  plano, iOS pausa el monitoreo (propio de iOS y del plugin usado).
- El **descubrimiento automático** del PC (mDNS) está configurado en el
  proyecto, pero en redes complicadas conviene conectar manualmente con la URL
  del servidor + API key.
- Esta guía instala **una versión de prueba** (firmada con tu Apple ID), no una
  versión distribuida en la App Store.