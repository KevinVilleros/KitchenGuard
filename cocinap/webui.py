import json
import os
import threading
import time
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs


_UI_HTML = r"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<title>CocinaP - Seguridad</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#111;color:#eee;padding:12px;max-width:600px;margin:0 auto}
h1{font-size:20px;margin:8px 0 12px;color:#ff9800;text-align:center}
.tabs{display:flex;gap:4px;margin-bottom:12px}
.tab{flex:1;padding:8px;text-align:center;background:#222;border:1px solid #333;border-radius:6px;cursor:pointer;font-size:14px;color:#aaa}
.tab.active{background:#ff9800;color:#111;border-color:#ff9800;font-weight:bold}
.panel{display:none;background:#1a1a1a;border-radius:8px;padding:12px}
.panel.active{display:block}
.card{background:#222;border-radius:6px;padding:10px;margin-bottom:8px}
.label{font-size:11px;color:#888;text-transform:uppercase}
.value{font-size:22px;font-weight:bold}
.grid{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px}
.badge{display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px;font-weight:bold}
.badge-fire{background:#f44336;color:#fff}
.badge-smoke{background:#9c27b0;color:#fff}
.badge-ok{background:#4caf50;color:#fff}
.badge-person{background:#2196f3;color:#fff}
.cfg-row{display:flex;justify-content:space-between;align-items:center;padding:6px 0;border-bottom:1px solid #2a2a2a;font-size:13px}
.cfg-row label{flex:1}
.cfg-row input,.cfg-row select{width:100px;padding:4px 6px;border:1px solid #444;border-radius:4px;background:#111;color:#eee;font-size:12px;text-align:right}
.cfg-row select{width:auto}
.cfg-cat{font-size:14px;color:#ff9800;margin:10px 0 4px;font-weight:bold}
.alarm-item{padding:6px 8px;border-left:3px solid #f44336;margin-bottom:4px;background:#222;border-radius:0 4px 4px 0;font-size:12px}
.alarm-item .ts{color:#888;font-size:10px}
.btn{padding:8px 16px;border:none;border-radius:6px;cursor:pointer;font-size:14px;font-weight:bold}
.btn-primary{background:#ff9800;color:#111}
.btn-primary:hover{background:#ffa726}
.btn-save{margin-top:8px;width:100%}
#save-msg{text-align:center;font-size:12px;margin-top:4px;color:#4caf50}
.armario{display:flex;gap:12px;align-items:center;justify-content:center;margin:12px 0;flex-wrap:wrap}
.armario-item{text-align:center}
.armario-val{font-size:32px;font-weight:bold}
.armario-label{font-size:11px;color:#888}
.sz-canvas-wrap{background:#000;border-radius:6px;margin:8px 0;position:relative;text-align:center}
#sz-canvas{width:100%;max-width:480px;cursor:crosshair;border-radius:4px;display:block;margin:0 auto;background:#1a1a2e}
.sz-coords{display:grid;grid-template-columns:1fr 1fr;gap:4px;margin-top:4px}
.sz-coords input{width:100%;padding:4px;border:1px solid #444;border-radius:4px;background:#111;color:#eee;font-size:12px;text-align:center}
</style>
</head>
<body>
<h1>🔒 CocinaP</h1>
<div class="tabs">
  <div class="tab active" onclick="showTab('dashboard')">Dashboard</div>
  <div class="tab" onclick="showTab('config')">Config</div>
  <div class="tab" onclick="showTab('alarms')">Alarmas</div>
</div>

<div id="panel-dashboard" class="panel active">
  <div class="grid">
    <div class="card"><div class="label">Fuego</div><div class="value" id="s-fire">-</div></div>
    <div class="card"><div class="label">Humo</div><div class="value" id="s-smoke">-</div></div>
    <div class="card"><div class="label">Personas</div><div class="value" id="s-persons">-</div></div>
  </div>
  <div class="card">
    <div class="label">Cobertura fuego</div>
    <div class="value" id="s-fire-cov" style="font-size:18px">-</div>
  </div>
  <div class="card">
    <div class="label">Estado</div>
    <div style="font-size:16px;margin-top:4px" id="s-status">-</div>
  </div>
  <div class="card">
    <div class="armario">
      <div class="armario-item"><div class="armario-val" id="s-zone-fire">0</div><div class="armario-label">Fuego estufa</div></div>
      <div class="armario-item"><div class="armario-val" id="s-zone-person">0</div><div class="armario-label">Persona</div></div>
      <div class="armario-item"><div class="armario-val" id="s-zone-pot">0</div><div class="armario-label">Ollas</div></div>
    </div>
  </div>
</div>

<div id="panel-config" class="panel">
  <div class="cfg-cat">Zona Estufa</div>
  <div style="font-size:11px;color:#888;margin-bottom:4px">Arrastrá el rectángulo para ajustar la zona de la estufa</div>
  <div class="sz-canvas-wrap">
    <canvas id="sz-canvas" width="480" height="270"></canvas>
  </div>
  <div class="sz-coords">
    <div><label style="font-size:11px;color:#888">X (%)</label><input id="sz-x" type="number" min="0" max="90" step="1" value="25"></div>
    <div><label style="font-size:11px;color:#888">Y (%)</label><input id="sz-y" type="number" min="0" max="90" step="1" value="35"></div>
    <div><label style="font-size:11px;color:#888">Ancho (%)</label><input id="sz-w" type="number" min="5" max="100" step="1" value="50"></div>
    <div><label style="font-size:11px;color:#888">Alto (%)</label><input id="sz-h" type="number" min="5" max="100" step="1" value="45"></div>
  </div>
  <div id="cfg-fields"></div>
  <button class="btn btn-primary btn-save" onclick="saveConfig()">Guardar</button>
  <div id="save-msg"></div>
</div>

<div id="panel-alarms" class="panel">
  <div style="display:flex;justify-content:space-between;margin-bottom:8px">
    <span style="color:#888;font-size:12px">Últimas alarmas</span>
    <button class="btn" style="padding:2px 10px;font-size:11px;background:#333;color:#eee" onclick="clearAlarms()">Limpiar</button>
  </div>
  <div id="alarm-list"></div>
</div>

<script>
const CFG_KEYS = [
  {k:'YOLO_CONFIDENCE',l:'Confianza YOLO',min:0.1,max:0.9,step:0.05},
  {k:'DETECTION_INTERVAL',l:'Intervalo detección (s)',min:0.05,max:1.0,step:0.05},
  {k:'DETECT_SCALE',l:'Escala detección',min:0.1,max:0.5,step:0.05},
  {k:'FIRE_COVERAGE_LOW',l:'Cobertura fuego BAJA',min:0.01,max:0.5,step:0.01},
  {k:'FIRE_COVERAGE_MEDIUM',l:'Cobertura fuego MEDIA',min:0.02,max:0.6,step:0.01},
  {k:'FIRE_COVERAGE_HIGH',l:'Cobertura fuego ALTA',min:0.05,max:0.8,step:0.01},
  {k:'FIRE_COVERAGE_CRITICAL',l:'Cobertura fuego CRÍTICA',min:0.1,max:0.9,step:0.01},
  {k:'FIRE_AREA_LARGE',l:'Área fuego grande (px)',min:1000,max:50000,step:500},
  {k:'FIRE_SUSTAINED_SECONDS',l:'Segundos fuego sostenido',min:2,max:30,step:1},
  {k:'FIRE_CONFIDENCE_THRESHOLD',l:'Umbral confianza fuego',min:0.2,max:0.9,step:0.05},
  {k:'SMOKE_COVERAGE_MIN',l:'Cobertura humo mínima',min:0.0001,max:0.05,step:0.0005},
  {k:'SMOKE_COVERAGE_HIGH',l:'Cobertura humo ALTA',min:0.02,max:0.5,step:0.01},
  {k:'SMOKE_CONFIDENCE_THRESHOLD',l:'Umbral confianza humo',min:0.2,max:0.9,step:0.05},
  {k:'SMOKE_EDGE_MAX',l:'Máx bordes humo',min:0.1,max:0.6,step:0.05},
  {k:'SMOKE_TEXTURE_MIN',l:'Textura humo mín',min:0.5,max:5.0,step:0.5},
  {k:'SMOKE_TEXTURE_MAX',l:'Textura humo máx',min:10,max:50,step:5},
  {k:'PERSON_HYSTERESIS_SECONDS',l:'Histéresis persona (s)',min:1,max:30,step:1},
  {k:'RISK_COOLDOWN',l:'Cooldown alertas (s)',min:1,max:30,step:1},
];

let alarms = [];
let szState = {x:25, y:35, w:50, h:45, dragging:false, mode:null, startX:0, startY:0, origX:0, origY:0, origW:0, origH:0};

function drawStoveZone() {
  const c = document.getElementById('sz-canvas');
  if (!c) return;
  const ctx = c.getContext('2d');
  const W = c.width, H = c.height;
  ctx.clearRect(0, 0, W, H);

  // grid background
  ctx.fillStyle = '#1a1a2e';
  ctx.fillRect(0, 0, W, H);
  ctx.strokeStyle = '#2a2a3e';
  ctx.lineWidth = 0.5;
  for (let i = 0; i <= 10; i++) {
    ctx.beginPath(); ctx.moveTo(i*W/10, 0); ctx.lineTo(i*W/10, H); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(0, i*H/10); ctx.lineTo(W, i*H/10); ctx.stroke();
  }

  const x = szState.x * W / 100;
  const y = szState.y * H / 100;
  const w = szState.w * W / 100;
  const h = szState.h * H / 100;

  // stove zone fill
  ctx.fillStyle = 'rgba(76, 175, 80, 0.25)';
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = '#4caf50';
  ctx.lineWidth = 2;
  ctx.strokeRect(x, y, w, h);

  // burners hint
  ctx.fillStyle = 'rgba(255, 152, 0, 0.15)';
  [[0.25,0.3],[0.75,0.3],[0.25,0.7],[0.75,0.7]].forEach(p => {
    const bx = x + p[0] * w, by = y + p[1] * h, br = Math.min(w, h) * 0.12;
    ctx.beginPath(); ctx.arc(bx, by, br, 0, Math.PI*2); ctx.fill();
  });

  // corner handles
  const hs = 6;
  const corners = [[x,y],[x+w,y],[x,y+h],[x+w,y+h]];
  corners.forEach(([cx,cy]) => {
    ctx.fillStyle = '#4caf50';
    ctx.fillRect(cx-hs, cy-hs, hs*2, hs*2);
    ctx.fillStyle = '#fff';
    ctx.fillRect(cx-hs+2, cy-hs+2, hs*2-4, hs*2-4);
  });

  // edge handles
  const mids = [[x+w/2,y],[x+w/2,y+h],[x,y+h/2],[x+w,y+h/2]];
  ctx.fillStyle = '#81c784';
  mids.forEach(([mx,my]) => {
    ctx.beginPath(); ctx.arc(mx, my, 4, 0, Math.PI*2); ctx.fill();
  });

  ctx.fillStyle = 'rgba(255,255,255,0.5)';
  ctx.font = '11px sans-serif';
  ctx.fillText(`${szState.w}% × ${szState.h}%`, x+4, y+14);
}

function hitTestSZ(mx, my) {
  const c = document.getElementById('sz-canvas');
  const W = c.width, H = c.height;
  const x = szState.x * W / 100, y = szState.y * H / 100;
  const w = szState.w * W / 100, h = szState.h * H / 100;
  const tol = 10;

  // corners
  const corners = [
    {mode:'tl', cx:x, cy:y}, {mode:'tr', cx:x+w, cy:y},
    {mode:'bl', cx:x, cy:y+h}, {mode:'br', cx:x+w, cy:y+h}
  ];
  for (const c of corners) {
    if (Math.hypot(mx-c.cx, my-c.cy) <= tol) return c.mode;
  }
  // edges
  if (mx >= x && mx <= x+w && Math.abs(my - y) <= tol) return 't';
  if (mx >= x && mx <= x+w && Math.abs(my - (y+h)) <= tol) return 'b';
  if (my >= y && my <= y+h && Math.abs(mx - x) <= tol) return 'l';
  if (my >= y && my <= y+h && Math.abs(mx - (x+w)) <= tol) return 'r';
  // inside
  if (mx >= x && mx <= x+w && my >= y && my <= y+h) return 'move';
  return null;
}

function szStartDrag(e) {
  const rect = document.getElementById('sz-canvas').getBoundingClientRect();
  const mx = (e.clientX - rect.left) * 480 / rect.width;
  const my = (e.clientY - rect.top) * 270 / rect.height;
  const mode = hitTestSZ(mx, my);
  if (!mode) return;
  szState.dragging = true;
  szState.mode = mode;
  szState.startX = mx;
  szState.startY = my;
  szState.origX = szState.x;
  szState.origY = szState.y;
  szState.origW = szState.w;
  szState.origH = szState.h;
}

function szDrag(e) {
  if (!szState.dragging) return;
  e.preventDefault();
  const rect = document.getElementById('sz-canvas').getBoundingClientRect();
  const mx = (e.clientX - rect.left) * 480 / rect.width;
  const my = (e.clientY - rect.top) * 270 / rect.height;
  const dx = (mx - szState.startX) * 100 / 480;
  const dy = (my - szState.startY) * 100 / 270;

  let nx = szState.origX, ny = szState.origY, nw = szState.origW, nh = szState.origH;
  const m = szState.mode;

  if (m === 'move') { nx = clamp(szState.origX + dx, 0, 100-szState.origW); ny = clamp(szState.origY + dy, 0, 100-szState.origH); }
  else if (m === 'e' || m === 'tr' || m === 'br' || m === 'r') { nw = clamp(szState.origW + dx, 5, 100-szState.origX); }
  else if (m === 'w' || m === 'tl' || m === 'bl' || m === 'l') { const dw = Math.min(dx, szState.origW - 5); nx = szState.origX + dw; nw = szState.origW - dw; }
  else if (m === 's' || m === 'b') { nh = clamp(szState.origH + dy, 5, 100-szState.origY); }
  else if (m === 'n' || m === 't') { const dh = Math.min(dy, szState.origH - 5); ny = szState.origY + dh; nh = szState.origH - dh; }

  szState.x = Math.round(clamp(nx, 0, 90));
  szState.y = Math.round(clamp(ny, 0, 90));
  szState.w = Math.round(clamp(nw, 5, 100 - szState.x));
  szState.h = Math.round(clamp(nh, 5, 100 - szState.y));
  syncSZInputs();
  drawStoveZone();
}

function szEndDrag() { szState.dragging = false; }

function syncSZInputs() {
  document.getElementById('sz-x').value = szState.x;
  document.getElementById('sz-y').value = szState.y;
  document.getElementById('sz-w').value = szState.w;
  document.getElementById('sz-h').value = szState.h;
}

function clamp(v, mn, mx) { return Math.max(mn, Math.min(mx, v)); }

function setupSZCanvas() {
  const c = document.getElementById('sz-canvas');
  if (!c) return;
  c.addEventListener('mousedown', szStartDrag);
  c.addEventListener('mousemove', szDrag);
  c.addEventListener('mouseup', szEndDrag);
  c.addEventListener('mouseleave', szEndDrag);
  c.addEventListener('touchstart', e => { const t = e.touches[0]; szStartDrag({clientX:t.clientX, clientY:t.clientY, preventDefault:()=>e.preventDefault()}); }, {passive:false});
  c.addEventListener('touchmove', e => { const t = e.touches[0]; szDrag({clientX:t.clientX, clientY:t.clientY, preventDefault:()=>e.preventDefault()}); }, {passive:false});
  c.addEventListener('touchend', szEndDrag);

  ['sz-x','sz-y','sz-w','sz-h'].forEach(id => {
    document.getElementById(id).addEventListener('input', () => {
      szState.x = parseFloat(document.getElementById('sz-x').value) || 0;
      szState.y = parseFloat(document.getElementById('sz-y').value) || 0;
      szState.w = parseFloat(document.getElementById('sz-w').value) || 5;
      szState.h = parseFloat(document.getElementById('sz-h').value) || 5;
      drawStoveZone();
    });
  });
}

function showTab(name) {
  document.querySelectorAll('.tab').forEach(t=>t.classList.remove('active'));
  document.querySelectorAll('.panel').forEach(p=>p.classList.remove('active'));
  document.querySelector(`.tab[onclick*="${name}"]`).classList.add('active');
  document.getElementById(`panel-${name}`).classList.add('active');
  if (name === 'config') loadConfig();
}

async function fetchJSON(url) {
  try {
    const r = await fetch(url);
    return await r.json();
  } catch(e) { return null; }
}

async function updateStatus() {
  const s = await fetchJSON('/api/status');
  if (!s) return;
  const fire = s.fire_regions || 0;
  const smoke = s.smoke_regions || 0;
  const persons = s.persons || 0;
  document.getElementById('s-fire').innerHTML = fire ? `<span class="badge badge-fire">${fire}</span>` : `<span class="badge badge-ok">0</span>`;
  document.getElementById('s-smoke').innerHTML = smoke ? `<span class="badge badge-smoke">${smoke}</span>` : `<span class="badge badge-ok">0</span>`;
  document.getElementById('s-persons').innerHTML = persons ? `<span class="badge badge-person">${persons}</span>` : `<span class="badge badge-ok">0</span>`;
  document.getElementById('s-fire-cov').textContent = s.fire_coverage != null ? (s.fire_coverage*100).toFixed(1)+'%' : '-';
  document.getElementById('s-status').textContent = s.status_text || '-';
  document.getElementById('s-zone-fire').textContent = s.fire_stove ? '🔥' : '○';
  document.getElementById('s-zone-person').textContent = persons ? '👤' : '○';
  document.getElementById('s-zone-pot').textContent = s.pots ? '🍳' : '○';
  if (s.last_alarm) {
    addAlarm(s.last_alarm);
  }
}

function addAlarm(a) {
  const exists = alarms.some(x => x.time === a.time && x.message === a.message);
  if (exists) return;
  alarms.unshift(a);
  renderAlarms();
}

function renderAlarms() {
  const list = document.getElementById('alarm-list');
  list.innerHTML = alarms.map(a =>
    `<div class="alarm-item"><span class="ts">${a.time||''}</span> [${a.severity}] ${a.message}</div>`
  ).join('');
}

function clearAlarms() {
  alarms = [];
  renderAlarms();
}

async function loadConfig() {
  const cfg = await fetchJSON('/api/config');
  if (!cfg) return;
  // restore stove zone
  if (cfg.STOVE_ZONE_X != null) { szState.x = Math.round(cfg.STOVE_ZONE_X * 100); }
  if (cfg.STOVE_ZONE_Y != null) { szState.y = Math.round(cfg.STOVE_ZONE_Y * 100); }
  if (cfg.STOVE_ZONE_W != null) { szState.w = Math.round(cfg.STOVE_ZONE_W * 100); }
  if (cfg.STOVE_ZONE_H != null) { szState.h = Math.round(cfg.STOVE_ZONE_H * 100); }
  syncSZInputs();
  drawStoveZone();
  const container = document.getElementById('cfg-fields');
  let html = '';
  let lastCat = '';
  CFG_KEYS.forEach(item => {
    const val = cfg[item.k];
    if (val === undefined) return;
    const cat = item.k.split('_')[0];
    if (cat !== lastCat) {
      html += `<div class="cfg-cat">${cat}</div>`;
      lastCat = cat;
    }
    html += `<div class="cfg-row"><label>${item.l}</label>`;
    if (typeof val === 'number' && val < 1 && val > -1) {
      html += `<input type="number" min="${item.min}" max="${item.max}" step="${item.step}" value="${val}" data-key="${item.k}">`;
    } else if (Number.isInteger(val) || (typeof val === 'number' && val >= 1)) {
      html += `<input type="number" min="${item.min}" max="${item.max}" step="${item.step||1}" value="${val}" data-key="${item.k}">`;
    } else {
      html += `<input type="text" value="${val}" data-key="${item.k}">`;
    }
    html += `</div>`;
  });
  container.innerHTML = html;
}

async function saveConfig() {
  const inputs = document.querySelectorAll('#cfg-fields input[data-key]');
  const updates = {};
  inputs.forEach(inp => {
    const key = inp.dataset.key;
    const raw = inp.value;
    updates[key] = raw.includes('.') ? parseFloat(raw) : parseInt(raw);
  });
  // stove zone
  updates.STOVE_ZONE_X = parseFloat((document.getElementById('sz-x').value || 25)) / 100;
  updates.STOVE_ZONE_Y = parseFloat((document.getElementById('sz-y').value || 35)) / 100;
  updates.STOVE_ZONE_W = parseFloat((document.getElementById('sz-w').value || 50)) / 100;
  updates.STOVE_ZONE_H = parseFloat((document.getElementById('sz-h').value || 45)) / 100;
  const r = await fetch('/api/config', {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify(updates),
  });
  const result = await r.json();
  const msg = document.getElementById('save-msg');
  msg.textContent = result.ok ? '✓ Guardado' : '✗ Error';
  setTimeout(() => msg.textContent = '', 2000);
}

setInterval(updateStatus, 1000);
updateStatus();
setupSZCanvas();
</script>
</body>
</html>"""


class _Handler(BaseHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.server_ref = None
        super().__init__(*args, **kwargs)

    def log_message(self, fmt, *args):
        pass  # suppress logs

    def _send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html):
        body = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"

        webui = getattr(self.server, "webui", None)

        if path == "/" or path == "":
            self._send_html(_UI_HTML)

        elif path == "/api/status" and webui:
            self._send_json(webui.get_status())

        elif path == "/api/config" and webui:
            self._send_json(webui.get_config())

        elif path == "/api/alarms" and webui:
            self._send_json(webui.get_alarms())

        else:
            self._send_json({"error": "not found"}, 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        webui = getattr(self.server, "webui", None)

        if path == "/api/config" and webui:
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b"{}"
            try:
                updates = json.loads(raw)
                ok = webui.update_config(updates)
                self._send_json({"ok": ok})
            except Exception as e:
                self._send_json({"ok": False, "error": str(e)}, 400)

        else:
            self._send_json({"error": "not found"}, 404)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()


class WebUI:
    def __init__(self, host="0.0.0.0", port=8080, open_browser=False):
        self.host = host
        self.port = port
        self.open_browser = open_browser
        self._server = None
        self._thread = None

        self._latest_status = {
            "fire_regions": 0, "smoke_regions": 0, "persons": 0,
            "fire_coverage": 0.0, "smoke_coverage": 0.0,
            "fire_stove": False, "pots": 0, "status_text": "✅ Iniciando...",
            "last_alarm": None,
        }
        self._alarms = []
        self._lock = threading.Lock()

    def get_status(self):
        with self._lock:
            return dict(self._latest_status)

    def get_config(self):
        import cocinap.config as cfg
        sz = cfg.STOVE_ZONE
        keys = [
            "YOLO_CONFIDENCE", "DETECTION_INTERVAL", "DETECT_SCALE",
            "FIRE_COVERAGE_LOW", "FIRE_COVERAGE_MEDIUM", "FIRE_COVERAGE_HIGH",
            "FIRE_COVERAGE_CRITICAL", "FIRE_AREA_LARGE", "FIRE_SUSTAINED_SECONDS",
            "FIRE_CONFIDENCE_THRESHOLD", "FIRE_AREA_MIN", "FIRE_STOVE_ZONE_ONLY",
            "SMOKE_COVERAGE_MIN", "SMOKE_COVERAGE_HIGH", "SMOKE_CONFIDENCE_THRESHOLD",
            "SMOKE_EDGE_MAX", "SMOKE_TEXTURE_MIN", "SMOKE_TEXTURE_MAX",
            "SMOKE_AREA_MIN", "SMOKE_STOVE_ZONE_ONLY",
            "PERSON_HYSTERESIS_SECONDS", "RISK_COOLDOWN",
        ]
        result = {k: getattr(cfg, k, None) for k in keys}
        result["STOVE_ZONE_X"] = sz["x"]
        result["STOVE_ZONE_Y"] = sz["y"]
        result["STOVE_ZONE_W"] = sz["w"]
        result["STOVE_ZONE_H"] = sz["h"]
        return result

    def update_config(self, updates):
        import cocinap.config as cfg
        try:
            # build stove zone from individual keys
            sz_keys = ["STOVE_ZONE_X", "STOVE_ZONE_Y", "STOVE_ZONE_W", "STOVE_ZONE_H"]
            sz_vals = {}
            for k in sz_keys:
                if k in updates:
                    sz_vals[k.split("_")[-1].lower()] = float(updates[k])
                    del updates[k]
            if len(sz_vals) == 4:
                cfg.STOVE_ZONE.update(sz_vals)

            for k, v in updates.items():
                if hasattr(cfg, k):
                    current = getattr(cfg, k)
                    if isinstance(current, bool):
                        setattr(cfg, k, bool(v))
                    elif isinstance(current, int):
                        setattr(cfg, k, int(v))
                    elif isinstance(current, float):
                        setattr(cfg, k, float(v))
                    else:
                        setattr(cfg, k, v)
            return True
        except Exception as e:
            print(f"[webui] config error: {e}")
            return False

    def get_alarms(self):
        with self._lock:
            return list(self._alarms[-50:])

    def push_status(self, detections, alerts, status_text):
        now = time.strftime("%H:%M:%S")
        last_alarm = None
        if alerts:
            worst = max(alerts, key=lambda a: (
                {"CRÍTICO": 3, "ALTO": 2, "MEDIO": 1, "BAJO": 0}.get(a.get("severity", ""), 0)
            ))
            last_alarm = {"time": now, "severity": worst["severity"], "message": worst["message"]}

        with self._lock:
            self._latest_status = {
                "fire_regions": len(detections.get("fire", [])),
                "smoke_regions": len(detections.get("smoke", [])),
                "persons": detections.get("persons", 0),
                "fire_coverage": detections.get("fire_coverage", 0.0),
                "smoke_coverage": detections.get("smoke_coverage", 0.0),
                "fire_stove": any(r.get("in_stove_zone", False) for r in detections.get("fire", [])),
                "pots": len(detections.get("pots_on_stove", [])),
                "status_text": status_text,
                "last_alarm": last_alarm,
            }
            if last_alarm:
                self._alarms.append(last_alarm)

    def start(self):
        class Handler(_Handler):
            pass

        server = HTTPServer((self.host, self.port), Handler)
        server.webui = self
        self._server = server

        self._thread = threading.Thread(target=server.serve_forever, daemon=True)
        self._thread.start()

        url = f"http://{self.host}:{self.port}"
        print(f"[webui] Servidor en {url}")
        if self.open_browser:
            webbrowser.open(url)

    def stop(self):
        if self._server:
            self._server.shutdown()
            self._server.server_close()
