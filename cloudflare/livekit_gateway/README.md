# CocinaP LiveKit Gateway

This Cloudflare Worker keeps LiveKit API credentials off the Flutter clients.
It registers an opaque device ID, creates one LiveKit RTMP ingress for the
Windows host, and issues short-lived tokens to paired phones for viewing video
and sending data-only monitoring controls.

The Worker is not deployed or configured with credentials by this repository.
Create a LiveKit Cloud project and a Cloudflare account before deployment.
Never put LiveKit API secrets in the Flutter app, source control, or QR codes.

## Configure

1. Install Node.js 20+ and run `npm install` in this directory.
2. Create the D1 database and replace `database_id` in `wrangler.jsonc`:

   ```powershell
   npx wrangler d1 create cocinap-livekit-gateway
   ```

3. Apply the migration locally and remotely:

   ```powershell
   npx wrangler d1 migrations apply cocinap-livekit-gateway --local
   npx wrangler d1 migrations apply cocinap-livekit-gateway --remote
   ```

4. Configure the following Worker secrets with `npx wrangler secret put NAME`:

   - `LIVEKIT_URL`: project WebSocket URL, for example `wss://project.livekit.cloud`
   - `LIVEKIT_API_KEY`
   - `LIVEKIT_API_SECRET`
   - `DATA_ENCRYPTION_KEY`: independent random secret of at least 32 characters
   - `IP_HASH_SECRET`: independent random secret used to rate-limit registrations

5. Deploy with `npm run deploy`. Keep the resulting `workers.dev` HTTPS URL;
   the Windows host and phones will use it as the CocinaP cloud gateway.

## API

- `POST /v1/devices/register` stores hashes of a new desktop owner key and
  phone viewer key. Device IDs are random 128-bit values; each key is random
  256-bit. The Windows app must generate these locally and retain them in
  secure storage.
- `POST /v1/devices/ingress` accepts `deviceId` and `ownerKey`, then creates or
  returns the device's RTMP ingress credentials. The stream key is encrypted
  before persistence in D1.
- `POST /v1/devices/token` accepts `deviceId` and `viewerKey`, then returns a
  15-minute LiveKit token that can subscribe and send data-only monitoring
  controls, but cannot publish audio or video.
- `POST /v1/devices/host-token` accepts `deviceId` and `ownerKey`, then returns
  a 15-minute LiveKit token that can publish data messages and subscribe to
  receive phone controls, but cannot publish audio/video.

The Windows app must publish its local MJPEG feed to the returned RTMP endpoint
(typically through FFmpeg); it must reconnect the publisher after a network or
camera interruption. It also joins the LiveKit room with the host token to send
person-detection and alert-state messages. The mobile app must request fresh
tokens before reconnecting.

This initial gateway has no account recovery or device revocation API. Do not
deploy it for customer use until pairing, revocation, operational monitoring,
and abuse limits have been added and tested.
