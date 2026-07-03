import time
import os
from cocinap.config import (
    FIRE_COVERAGE_LOW, FIRE_COVERAGE_MEDIUM, FIRE_COVERAGE_HIGH, FIRE_COVERAGE_CRITICAL,
    FIRE_AREA_LARGE, FIRE_SUSTAINED_SECONDS,
    FIRE_HISTORY_FRAMES, SMOKE_HISTORY_FRAMES, SMOKE_COVERAGE_MIN, SMOKE_COVERAGE_HIGH,
    PERSON_HYSTERESIS_SECONDS,
    UNATTENDED_WARN_MINUTES, UNATTENDED_WARN_HIGH_MINUTES, UNATTENDED_ALARM_MINUTES,
    RISK_COOLDOWN, EVENT_LOG_FILE,
)


class RiskAnalyzer:
    def __init__(self):
        self.last_person_time = time.time()
        self.consecutive_no_person = 0
        self.consecutive_yes_person = 0

        self.fire_history = []
        self.smoke_history = []
        self._fire_sustained_count = 0
        self._fire_sustained_start = 0.0

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
        if coverage >= FIRE_COVERAGE_CRITICAL:
            return "CRÍTICO"
        if coverage >= FIRE_COVERAGE_HIGH:
            return "ALTO"
        if coverage >= FIRE_COVERAGE_MEDIUM:
            return "MEDIO"
        if coverage >= FIRE_COVERAGE_LOW:
            return "BAJO"
        return None

    def _max_fire_confidence(self, detections):
        return max((r["confidence"] for r in detections.get("fire", [])), default=0.0)

    def _fire_in_stove(self, detections):
        return any(r.get("in_stove_zone", False) for r in detections.get("fire", []))

    def _max_fire_area(self, detections):
        return max((r["area"] for r in detections.get("fire", [])), default=0)

    def _fire_large_present(self, detections):
        fire_cov = detections["fire_coverage"]
        max_area = self._max_fire_area(detections)
        return fire_cov >= FIRE_COVERAGE_MEDIUM or max_area >= FIRE_AREA_LARGE

    def analyze(self, detections):
        current_time = time.time()
        alerts = []

        has_person = detections["persons"] > 0
        fire_regions = detections["fire"]
        n_fire = len(fire_regions)
        fire_cov = detections["fire_coverage"]
        fire_valid = detections["fire_has_valid"]
        max_conf = self._max_fire_confidence(detections)
        fire_in_stove = self._fire_in_stove(detections)
        max_fire_area = self._max_fire_area(detections)

        smoke_regions = detections["smoke"]
        n_smoke = len(smoke_regions)
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
        valid_fire_now = fire_valid and n_fire > 0

        self.fire_history.append(valid_fire_now)
        if len(self.fire_history) > FIRE_HISTORY_FRAMES:
            self.fire_history.pop(0)

        fire_stable = sum(self.fire_history) >= FIRE_HISTORY_FRAMES // 2

        # ---- Condition 1: Fire on stove with NO person ----
        if fire_in_stove and not has_person and valid_fire_now:
            level = self._get_fire_level(fire_cov) or "BAJO"
            severity = level if level else "BAJO"
            alerts.append({
                "type": "FUEGO_DESATENDIDO",
                "severity": severity,
                "message": (
                    f"🔥 Fuego en estufa sin supervisión"
                    f" ({fire_cov:.1%}, conf:{max_conf:.0%})"
                ),
                "confidence": max_conf,
                "coverage": fire_cov,
                "in_stove": True,
            })

        # ---- Condition 2: Large fire sustained >7 seconds ----
        is_large = self._fire_large_present(detections) and valid_fire_now
        if is_large:
            if self._fire_sustained_count == 0:
                self._fire_sustained_start = current_time
            self._fire_sustained_count += 1
            sustained = current_time - self._fire_sustained_start
            if sustained >= FIRE_SUSTAINED_SECONDS:
                level = self._get_fire_level(fire_cov) or "ALTO"
                alerts.append({
                    "type": "FUEGO_SOSTENIDO",
                    "severity": "CRÍTICO" if level == "CRÍTICO" else "ALTO",
                    "message": (
                        f"🔥 FUEGO INTENSO {sustained:.0f}s"
                        f" ({fire_cov:.1%}, área:{max_fire_area})"
                    ),
                    "confidence": min(max_conf + 0.1, 0.95),
                    "coverage": fire_cov,
                    "in_stove": fire_in_stove,
                })
        else:
            self._fire_sustained_count = 0
            self._fire_sustained_start = 0.0

        # ---- Traditional fire alerts (stable fire in stove or outside) ----
        if fire_stable and valid_fire_now and not fire_in_stove:
            level = self._get_fire_level(fire_cov) or "BAJO"
            alerts.append({
                "type": "FUEGO",
                "severity": level,
                "message": (
                    f"🔥 Fuego fuera de la estufa"
                    f" ({fire_cov:.1%}, conf:{max_conf:.0%})"
                ),
                "confidence": max_conf,
                "coverage": fire_cov,
                "in_stove": False,
            })

        # ---- Condition 3: Abundant smoke ----
        cooking_steam = has_person and (n_pots > 0 or (smoke_cov > 0 and not valid_fire_now))
        is_real_smoke = smoke_cov >= SMOKE_COVERAGE_MIN and not cooking_steam

        self.smoke_history.append(is_real_smoke)
        if len(self.smoke_history) > SMOKE_HISTORY_FRAMES:
            self.smoke_history.pop(0)
        smoke_stable = sum(self.smoke_history) >= SMOKE_HISTORY_FRAMES // 2

        if smoke_stable and is_real_smoke:
            if smoke_cov >= SMOKE_COVERAGE_HIGH:
                alerts.append({
                    "type": "HUMO_ABUNDANTE",
                    "severity": "CRÍTICO",
                    "message": f"💨 Humo abundante ({smoke_cov:.1%})",
                    "confidence": min(smoke_cov / 0.1, 0.9),
                    "coverage": smoke_cov,
                })
            else:
                has_fire_nearby = fire_stable and valid_fire_now
                if has_fire_nearby:
                    alerts.append({
                        "type": "HUMO", "severity": "ALTO",
                        "message": f"💨 Humo + fuego ({smoke_cov:.1%})",
                        "confidence": min(smoke_cov / 0.1, 0.9),
                        "coverage": smoke_cov,
                    })
                else:
                    alerts.append({
                        "type": "HUMO", "severity": "MEDIO",
                        "message": f"💨 Humo en cocina ({smoke_cov:.1%})",
                        "confidence": min(smoke_cov / 0.1, 0.7),
                        "coverage": smoke_cov,
                    })

        # ---- Unattended pots (existing logic) ----
        if n_pots > 0 and not has_person:
            person_has_left = self.consecutive_no_person >= PERSON_HYSTERESIS_SECONDS
            if person_has_left:
                unattended_minutes = person_absent_for / 60.0

                if unattended_minutes >= UNATTENDED_ALARM_MINUTES:
                    alerts.append({
                        "type": "OLVIDO_CRITICO", "severity": "CRÍTICO",
                        "message": f"🚨 COCINA OLVIDADA {int(unattended_minutes)} min! ({n_pots} olla/s)",
                        "confidence": min(unattended_minutes / (UNATTENDED_ALARM_MINUTES + 10), 0.95),
                    })
                elif unattended_minutes >= UNATTENDED_WARN_HIGH_MINUTES:
                    alerts.append({
                        "type": "OLVIDO_ALTO", "severity": "ALTO",
                        "message": f"⚠️ Cocina desatendida {int(unattended_minutes)} min ({n_pots} olla/s)",
                        "confidence": min(unattended_minutes / UNATTENDED_ALARM_MINUTES, 0.8),
                    })
                elif unattended_minutes >= UNATTENDED_WARN_MINUTES:
                    alerts.append({
                        "type": "OLVIDO", "severity": "MEDIO",
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

        # CRÍTICO severity → fire alarm (includes HUMO_ABUNDANTE, FUEGO_SOSTENIDO CRÍTICO)
        for a in alerts:
            if a["severity"] == "CRÍTICO":
                self.last_alert_time = current_time
                self._log_event(f"ALARMA {a['type']} - {a['message']}")
                alarm_type = "smoke" if a["type"] in ("HUMO_ABUNDANTE", "HUMO") else "fire"
                return True, alarm_type

        # FUEGO_DESATENDIDO → fire alarm (stove unattended)
        for a in alerts:
            if a["type"] == "FUEGO_DESATENDIDO":
                self.last_alert_time = current_time
                self._log_event(f"ALARMA {a['type']} - {a['message']}")
                return True, "fire"

        # FUEGO_SOSTENIDO → fire alarm
        for a in alerts:
            if a["type"] == "FUEGO_SOSTENIDO":
                self.last_alert_time = current_time
                self._log_event(f"ALARMA {a['type']} - {a['message']}")
                return True, "fire"

        # Unattended critical/alto
        for a in alerts:
            if a["type"] in ("OLVIDO_CRITICO", "OLVIDO_ALTO"):
                self.last_alert_time = current_time
                self._log_event(f"ALARMA {a['type']} - {a['message']}")
                return True, "unattended"

        # Fire outside stove at ALTO
        for a in alerts:
            if a["type"] == "FUEGO" and a["severity"] == "ALTO":
                self.last_alert_time = current_time
                self._log_event(f"ALERTA {a['type']} - {a['message']}")
                return True, "fire"

        # HUMO abundant or HUMO + FUEGO at ALTO
        for a in alerts:
            if a["type"] in ("HUMO",) and a["severity"] == "ALTO":
                self.last_alert_time = current_time
                self._log_event(f"ALERTA {a['type']} - {a['message']}")
                return True, "smoke"

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
