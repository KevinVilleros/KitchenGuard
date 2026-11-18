interface Env {
  DB: D1Database;
  LIVEKIT_URL: string;
  LIVEKIT_API_KEY: string;
  LIVEKIT_API_SECRET: string;
  DATA_ENCRYPTION_KEY: string;
  IP_HASH_SECRET: string;
}

interface DeviceRow {
  device_id: string;
  room_name: string;
  owner_key_hash: string;
  viewer_key_hash: string;
  ingress_url: string | null;
  ingress_key_cipher: string | null;
}

const HEX_32 = /^[a-f0-9]{32}$/i;
const HEX_64 = /^[a-f0-9]{64}$/i;
const BODY_LIMIT = 4096;
const REGISTRATION_LIMIT_PER_DAY = 12;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      if (request.method !== "POST") {
        return json({ error: "method_not_allowed" }, 405);
      }

      const path = new URL(request.url).pathname;
      if (path === "/v1/devices/register") {
        return await registerDevice(request, env);
      }
      if (path === "/v1/devices/ingress") {
        return await createOrGetIngress(request, env);
      }
      if (path === "/v1/devices/token") {
        return await issueViewerToken(request, env);
      }
      if (path === "/v1/devices/host-token") {
        return await issueHostToken(request, env);
      }
      return json({ error: "not_found" }, 404);
    } catch (error) {
      console.error("LiveKit gateway request failed", error);
      return json({ error: "service_unavailable" }, 503);
    }
  },
};

async function registerDevice(request: Request, env: Env): Promise<Response> {
  const ip = request.headers.get("CF-Connecting-IP");
  if (!ip) return json({ error: "registration_unavailable" }, 503);
  if (!(await allowRegistration(ip, env))) {
    return json({ error: "registration_rate_limited" }, 429);
  }

  const body = await readBody(request);
  const deviceId = readString(body, "deviceId");
  const ownerKey = readString(body, "ownerKey");
  const viewerKey = readString(body, "viewerKey");
  if (
    !deviceId ||
    !ownerKey ||
    !viewerKey ||
    !HEX_32.test(deviceId) ||
    !HEX_64.test(ownerKey) ||
    !HEX_64.test(viewerKey) ||
    ownerKey.toLowerCase() === viewerKey.toLowerCase()
  ) {
    return json({ error: "invalid_device_registration" }, 400);
  }

  const roomName = `cocinap-${deviceId.toLowerCase()}`;
  const result = await env.DB.prepare(
    `INSERT OR IGNORE INTO devices
      (device_id, room_name, owner_key_hash, viewer_key_hash, created_at)
     VALUES (?, ?, ?, ?, ?)`,
  )
    .bind(
      deviceId.toLowerCase(),
      roomName,
      await sha256(ownerKey),
      await sha256(viewerKey),
      Math.floor(Date.now() / 1000),
    )
    .run();

  if (result.meta.changes !== 1) {
    return json({ error: "device_already_registered" }, 409);
  }
  return json({ registered: true }, 201);
}

async function createOrGetIngress(
  request: Request,
  env: Env,
): Promise<Response> {
  const body = await readBody(request);
  const deviceId = readString(body, "deviceId");
  const ownerKey = readString(body, "ownerKey");
  if (!deviceId || !ownerKey || !HEX_32.test(deviceId) || !HEX_64.test(ownerKey)) {
    return json({ error: "invalid_credentials" }, 400);
  }

  const device = await findDevice(env, deviceId);
  if (!device || !(await matches(ownerKey, device.owner_key_hash))) {
    return json({ error: "unauthorized" }, 401);
  }

  if (device.ingress_url && device.ingress_key_cipher) {
    return json({
      url: device.ingress_url,
      streamKey: await decrypt(device.ingress_key_cipher, env),
    });
  }

  const ingress = await createLiveKitIngress(device, env);
  const encryptedKey = await encrypt(ingress.streamKey, env);
  await env.DB.prepare(
    `UPDATE devices
     SET ingress_url = ?, ingress_key_cipher = ?
     WHERE device_id = ? AND ingress_url IS NULL`,
  )
    .bind(ingress.url, encryptedKey, device.device_id)
    .run();

  const saved = await findDevice(env, device.device_id);
  if (!saved?.ingress_url || !saved.ingress_key_cipher) {
    throw new Error("Ingress credentials were not persisted.");
  }
  return json({
    url: saved.ingress_url,
    streamKey: await decrypt(saved.ingress_key_cipher, env),
  });
}

async function issueViewerToken(
  request: Request,
  env: Env,
): Promise<Response> {
  const body = await readBody(request);
  const deviceId = readString(body, "deviceId");
  const viewerKey = readString(body, "viewerKey");
  if (
    !deviceId ||
    !viewerKey ||
    !HEX_32.test(deviceId) ||
    !HEX_64.test(viewerKey)
  ) {
    return json({ error: "invalid_credentials" }, 400);
  }

  const device = await findDevice(env, deviceId);
  if (!device || !(await matches(viewerKey, device.viewer_key_hash))) {
    return json({ error: "unauthorized" }, 401);
  }

  const now = Math.floor(Date.now() / 1000);
  const token = await signJwt(
    {
      iss: env.LIVEKIT_API_KEY,
      sub: `viewer-${crypto.randomUUID()}`,
      nbf: now - 5,
      exp: now + 15 * 60,
      video: {
        roomJoin: true,
        room: device.room_name,
        canSubscribe: true,
        canPublish: false,
        canPublishData: true,
      },
    },
    env.LIVEKIT_API_SECRET,
  );
  return json({ serverUrl: env.LIVEKIT_URL, token, expiresIn: 900 });
}

async function issueHostToken(request: Request, env: Env): Promise<Response> {
  const body = await readBody(request);
  const deviceId = readString(body, "deviceId");
  const ownerKey = readString(body, "ownerKey");
  if (!deviceId || !ownerKey || !HEX_32.test(deviceId) || !HEX_64.test(ownerKey)) {
    return json({ error: "invalid_credentials" }, 400);
  }

  const device = await findDevice(env, deviceId);
  if (!device || !(await matches(ownerKey, device.owner_key_hash))) {
    return json({ error: "unauthorized" }, 401);
  }

  const now = Math.floor(Date.now() / 1000);
  const token = await signJwt(
    {
      iss: env.LIVEKIT_API_KEY,
      sub: `host-${device.device_id}`,
      nbf: now - 5,
      exp: now + 15 * 60,
      video: {
        roomJoin: true,
        room: device.room_name,
        canPublish: false,
        canPublishData: true,
        canSubscribe: true,
      },
    },
    env.LIVEKIT_API_SECRET,
  );
  return json({ serverUrl: env.LIVEKIT_URL, token, expiresIn: 900 });
}

async function createLiveKitIngress(
  device: DeviceRow,
  env: Env,
): Promise<{ url: string; streamKey: string }> {
  const now = Math.floor(Date.now() / 1000);
  const apiToken = await signJwt(
    {
      iss: env.LIVEKIT_API_KEY,
      sub: `cocinap-${device.device_id}`,
      nbf: now - 5,
      exp: now + 60,
      video: { ingressAdmin: true },
    },
    env.LIVEKIT_API_SECRET,
  );
  const baseUrl = new URL(env.LIVEKIT_URL);
  if (baseUrl.protocol !== "wss:" || baseUrl.pathname !== "/") {
    throw new Error("LIVEKIT_URL must be a WSS origin.");
  }
  baseUrl.protocol = "https:";
  baseUrl.pathname = "/twirp/livekit.Ingress/CreateIngress";

  const response = await fetch(baseUrl, {
    method: "POST",
    headers: {
      authorization: `Bearer ${apiToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      inputType: 0,
      name: `CocinaP ${device.device_id}`,
      roomName: device.room_name,
      participantIdentity: `host-${device.device_id}`,
      participantName: "CocinaP Windows",
    }),
  });
  if (!response.ok) {
    throw new Error(`LiveKit ingress creation failed: HTTP ${response.status}`);
  }
  const info: unknown = await response.json();
  if (
    typeof info !== "object" ||
    info === null ||
    !("url" in info) ||
    typeof info.url !== "string" ||
    !("streamKey" in info) ||
    typeof info.streamKey !== "string"
  ) {
    throw new Error("LiveKit returned an invalid ingress response.");
  }
  return { url: info.url, streamKey: info.streamKey };
}

async function findDevice(
  env: Env,
  deviceId: string,
): Promise<DeviceRow | null> {
  return env.DB.prepare(
    `SELECT device_id, room_name, owner_key_hash, viewer_key_hash,
            ingress_url, ingress_key_cipher
     FROM devices WHERE device_id = ?`,
  )
    .bind(deviceId.toLowerCase())
    .first<DeviceRow>();
}

async function allowRegistration(ip: string, env: Env): Promise<boolean> {
  const now = Math.floor(Date.now() / 1000);
  const dayBucket = Math.floor(now / 86400);
  const ipHash = await hmacHex(env.IP_HASH_SECRET, ip);
  await env.DB.prepare(
    `INSERT INTO registration_limits (ip_hash, day_bucket, request_count)
     VALUES (?, ?, 1)
     ON CONFLICT(ip_hash, day_bucket)
     DO UPDATE SET request_count = request_count + 1`,
  )
    .bind(ipHash, dayBucket)
    .run();
  const count = await env.DB.prepare(
    `SELECT request_count FROM registration_limits
     WHERE ip_hash = ? AND day_bucket = ?`,
  )
    .bind(ipHash, dayBucket)
    .first<{ request_count: number }>();
  return (count?.request_count ?? REGISTRATION_LIMIT_PER_DAY + 1) <=
    REGISTRATION_LIMIT_PER_DAY;
}

async function readBody(request: Request): Promise<Record<string, unknown>> {
  const contentLength = Number(request.headers.get("Content-Length") ?? 0);
  if (contentLength > BODY_LIMIT) throw new Error("Request body is too large.");
  const text = await request.text();
  if (new TextEncoder().encode(text).length > BODY_LIMIT) {
    throw new Error("Request body is too large.");
  }
  const value: unknown = JSON.parse(text);
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("Request body must be an object.");
  }
  return value as Record<string, unknown>;
}

function readString(body: Record<string, unknown>, key: string): string | null {
  const value = body[key];
  return typeof value === "string" ? value : null;
}

async function matches(value: string, expectedHash: string): Promise<boolean> {
  const actualHash = await sha256(value);
  if (actualHash.length !== expectedHash.length) return false;
  let difference = 0;
  for (let index = 0; index < actualHash.length; index++) {
    difference |= actualHash.charCodeAt(index) ^ expectedHash.charCodeAt(index);
  }
  return difference === 0;
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return bytesToHex(new Uint8Array(digest));
}

async function hmacHex(secret: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value));
  return bytesToHex(new Uint8Array(digest));
}

async function encrypt(value: string, env: Env): Promise<string> {
  const key = await encryptionKey(env);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    new TextEncoder().encode(value),
  );
  return `${toBase64Url(iv)}.${toBase64Url(new Uint8Array(ciphertext))}`;
}

async function decrypt(value: string, env: Env): Promise<string> {
  const [encodedIv, encodedCiphertext, extra] = value.split(".");
  if (!encodedIv || !encodedCiphertext || extra !== undefined) {
    throw new Error("Stored ingress credentials are invalid.");
  }
  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: fromBase64Url(encodedIv) },
    await encryptionKey(env),
    fromBase64Url(encodedCiphertext),
  );
  return new TextDecoder().decode(plaintext);
}

async function encryptionKey(env: Env): Promise<CryptoKey> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(env.DATA_ENCRYPTION_KEY),
  );
  return crypto.subtle.importKey("raw", digest, "AES-GCM", false, [
    "encrypt",
    "decrypt",
  ]);
}

async function signJwt(
  claims: Record<string, unknown>,
  secret: string,
): Promise<string> {
  const encodedHeader = toBase64Url(
    new TextEncoder().encode(JSON.stringify({ alg: "HS256", typ: "JWT" })),
  );
  const encodedClaims = toBase64Url(
    new TextEncoder().encode(JSON.stringify(claims)),
  );
  const payload = `${encodedHeader}.${encodedClaims}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(payload),
  );
  return `${payload}.${toBase64Url(new Uint8Array(signature))}`;
}

function toBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  }
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function fromBase64Url(value: string): Uint8Array {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(base64 + "=".repeat((4 - (base64.length % 4)) % 4));
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}
