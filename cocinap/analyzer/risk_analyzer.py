import time
import os
from cocinap.config import (
    FIRE_COVERAGE_LOW, FIRE_COVERAGE_MEDIUM, FIRE_COVERAGE_HIGH,
    FIRE_HISTORY_FRAMES, SMOKE_HISTORY_FRAMES,
    PERSON_HYSTERESIS_SECONDS,
    UNATTENDED_WARN_MINUTES, UNATTENDED_WARN_HIGH_MINUTES, UNATTENDED_ALARM_MINUTES,
    RISK_COOLDOWN, EVENT_LOG_FILE,
)


class RiskAnalyzer:
    def __init__(self):
        self.last_person_time = time.time()
        self.last_person_leave_time = None
        self.unattended_accumulated = 0.0
        self.consecutive_no_person = 0
        self.consecutive_yes_person = 0

        self.fire_history = []
        self.smoke_history = []

        self.last_alert_time = 0
        self._log_path = EVENT_LOG_FILE

        self._log_event("Sistema iniciado")

    def _log_event(self, msg):
        try:
            ts = time.strftime("%Y-%m-%d %H:%M:%S")
            with open(self._log_path, "a", encoding="utf-8") as f:
                f.write(f"[{ts}] {msg}\n")
        except Exception:
            pass

    def _get_fire_level(self, coverage):
        if coverage >= FIRE_COVERAGE_HIGH:
            return "ALTO"
        if coverage >= FIRE_COVERAGE_MEDIUM:
            return "MEDIO"
        if coverage >= FIRE_COVERAGE_LOW:
            return "BAJO"
        return None

    def analyze(self, detections):
        current_time = time.time()
        alerts = []

        has_person = detections["persons"] > 0
        n_fire = len(detections["fire"])
        fire_cov = detections["fire_coverage"]
        fire_moving = detections["fire_movement_valid"]
        n_smoke = len(detections["smoke"])
        smoke_cov = detections["smoke_coverage"]
        n_pots = len(detections["pots_on_stove"])

        if has_person:
            self.consecutive_no_person = 0
            self.consecutive_yes_person += 1
            if self.consecutive_yes_person >= 2:
                self.last_person_time = current_time
        else:
            self.consecutive_no_person += 1
            self.consecutive_yes_person = 0

        person_absent_for = current_time - self.last_person_time

        self.fire_history.append({"count": n_fire, "coverage": fire_cov, "moving": fire_moving})
        if len(self.fire_history) > FIRE_HISTORY_FRAMES:
            self.fire_history.pop(0)

        fire_ok_frames = sum(1 for f in self.fire_history if f["count"] > 0)
        fire_stable = fire_ok_frames >= FIRE_HISTORY_FRAMES // 2
        fire_has_movement = any(f["moving"] for f in self.fire_history)
        avg_coverage = sum(f["coverage"] for f in self.fire_history) / max(len(self.fire_history), 1)

        self.smoke_history.append(n_smoke > 0)
        if len(self.smoke_history) > SMOKE_HISTORY_FRAMES:
            self.smoke_history.pop(0)
        smoke_stable = sum(self.smoke_history) >= SMOKE_HISTORY_FRAMES // 2

        if fire_stable and fire_has_movement:
            fire_level = self._get_fire_level(avg_coverage)
            if fire_level:
                label_map = {"BAJO": "bajo", "MEDIO": "medio", "ALTO": "grande"}
                alerts.append({
                    "type": "FUEGO",
                    "severity": fire_level,
                    "message": f"🔥 Fuego {label_map[fire_level]} detectado ({avg_coverage:.1%} del frame)",
                    "confidence": min(avg_coverage / FIRE_COVERAGE_HIGH, 0.95),
                    "coverage": avg_coverage,
                })
        elif fire_stable and not fire_has_movement and n_fire > 0:
            alerts.append({
                "type": "FUEGO_ESTATICO",
                "severity": "BAJO",
                "message": "ℹ️ Zona caliente detectada (sin movimiento)",
                "confidence": 0.3,
                "coverage": avg_coverage,
            })

        if smoke_stable:
            alerts.append({
                "type": "HUMO",
                "severity": "ALTO" if smoke_cov > 0.05 else "MEDIO",
                "message": f"💨 Humo detectado ({smoke_cov:.1%} del frame)",
                "confidence": min(smoke_cov / 0.1, 0.9),
                "coverage": smoke_cov,
            })

        if n_pots > 0 and not has_person:
            person_has_left = self.consecutive_no_person >= PERSON_HYSTERESIS_SECONDS
            if person_has_left:
                unattended_minutes = person_absent_for / 60.0

                if unattended_minutes >= UNATTENDED_ALARM_MINUTES:
                    alerts.append({
                        "type": "OLVIDO_CRITICO",
                        "severity": "CRÍTICO",
                        "message": f"🚨 COCINA OLVIDADA {int(unattended_minutes)} min! ({n_pots} olla/s en el fuego)",
                        "confidence": min(unattended_minutes / (UNATTENDED_ALARM_MINUTES + 10), 0.95),
                    })
                elif unattended_minutes >= UNATTENDED_WARN_HIGH_MINUTES:
                    alerts.append({
                        "type": "OLVIDO_ALTO",
                        "severity": "ALTO",
                        "message": f"⚠️ Cocina desatendida {int(unattended_minutes)} min! ({n_pots} olla/s)",
                        "confidence": min(unattended_minutes / UNATTENDED_ALARM_MINUTES, 0.8),
                    })
                elif unattended_minutes >= UNATTENDED_WARN_MINUTES:
                    alerts.append({
                        "type": "OLVIDO",
                        "severity": "MEDIO",
                        "message": f"⏱ Cocina desatendida {int(unattended_minutes)} min",
                        "confidence": min(unattended_minutes / UNATTENDED_WARN_HIGH_MINUTES, 0.6),
                    })

        return alerts

    def should_trigger_alarm(self, alerts):
        current_time = time.time()
        if not alerts:
            return False, None
        if current_time - self.last_alert_time < RISK_COOLDOWN:
            return False, None

        for a in alerts:
            if a["severity"] in ("CRÍTICO",):
                self.last_alert_time = current_time
                self._log_event(f"ALARMA {a['type']} - {a['message']}")
                return True, "fire"
            if a["severity"] == "ALTO":
                if a["type"] in ("OLVIDO_CRITICO", "OLVIDO_ALTO"):
                    self.last_alert_time = current_time
                    self._log_event(f"ALARMA {a['type']} - {a['message']}")
                    return True, "unattended"

        for a in alerts:
            if a["severity"] in ("ALTO",):
                self.last_alert_time = current_time
                self._log_event(f"ALERTA {a['type']} - {a['message']}")
                return True, "fire"

        return False, None

    def _severity_level(self, severity):
        levels = {"CRÍTICO": 3, "ALTO": 2, "MEDIO": 1, "BAJO": 0}
        return levels.get(severity, 0)

    def get_status_text(self, alerts, detections):
        if not alerts:
            n_pots = len(detections.get("pots_on_stove", []))
            has_person = detections.get("persons", 0) > 0
            if n_pots > 0 and not has_person:
                return "✅ Vigilando... ollas en el fuego"
            return "✅ Cocina segura"

        worst = max(alerts, key=lambda a: self._severity_level(a["severity"]))
        return worst["message"]

    def get_status_color(self, alerts):
        if not alerts:
            return (0, 255, 0)
        worst = max(alerts, key=lambda a: self._severity_level(a["severity"]))
        if worst["severity"] == "CRÍTICO":
            return (0, 0, 255)
        if worst["severity"] == "ALTO":
            return (0, 165, 255)
        if worst["severity"] == "MEDIO":
            return (0, 255, 255)
        return (0, 255, 0)
