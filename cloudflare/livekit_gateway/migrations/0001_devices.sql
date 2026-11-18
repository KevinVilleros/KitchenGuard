CREATE TABLE devices (
  device_id TEXT PRIMARY KEY,
  room_name TEXT NOT NULL UNIQUE,
  owner_key_hash TEXT NOT NULL,
  viewer_key_hash TEXT NOT NULL,
  ingress_url TEXT,
  ingress_key_cipher TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE registration_limits (
  ip_hash TEXT NOT NULL,
  day_bucket INTEGER NOT NULL,
  request_count INTEGER NOT NULL,
  PRIMARY KEY (ip_hash, day_bucket)
);
