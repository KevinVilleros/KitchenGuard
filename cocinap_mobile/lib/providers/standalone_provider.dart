import 'dart:async';
import 'package:flutter/foundation.dart';

/// Estado del modo de la app: conectado al PC o funcionando sola (standalone).
enum AppMode { pc, standalone }

/// Resultado de una alerta por cocina desatendida.
class StandaloneAlert {
  final String message;
  final DateTime time;
  const StandaloneAlert(this.message, this.time);
}

/// Proveedor del modo standalone: monitoreo con cámara del móvil,
/// temporizador configurable y alertas si no hay persona en la cocina.
class StandaloneProvider extends ChangeNotifier {
  AppMode _mode = AppMode.pc;

  // --- Timer de monitoreo ---
  int _durationMinutes = 30;
  int _remainingSeconds = 0;
  bool _timerRunning = false;
  bool _timerPaused = false;
  Timer? _timerTick;

  // --- Detección de persona ---
  bool _personPresent = false;
  DateTime? _lastPersonSeen;
  bool _cameraActive = false;

  // --- Configuración ---
  double _confidence = 0.5;
  int _noPersonAlertSeconds = 30; // alerta si no hay persona este tiempo

  // Alerta se dispara si pasa este tiempo SEGUIDO sin persona (configurable)
  int _dangerMinutes = 5; // tiempo peligroso sin atender la cocina

  final List<StandaloneAlert> _alerts = [];
  bool _alerted = false;

  AppMode get mode => _mode;
  int get durationMinutes => _durationMinutes;
  int get remainingSeconds => _remainingSeconds;
  bool get timerRunning => _timerRunning;
  bool get timerPaused => _timerPaused;
  bool get personPresent => _personPresent;
  bool get cameraActive => _cameraActive;
  double get confidence => _confidence;
  int get noPersonAlertSeconds => _noPersonAlertSeconds;
  int get dangerMinutes => _dangerMinutes;
  List<StandaloneAlert> get alerts => _alerts;

  String get modeLabel => _mode == AppMode.pc ? "Conectado al PC" : "Modo independiente";

  void setMode(AppMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    if (mode == AppMode.pc) {
      stopTimer();
    }
    notifyListeners();
  }

  // --- Timer ---

  void setDurationMinutes(int minutes) {
    _durationMinutes = minutes.clamp(1, 240).toInt();
    notifyListeners();
  }

  void startTimer({int? minutes}) {
    if (minutes != null) setDurationMinutes(minutes);
    _remainingSeconds = _durationMinutes * 60;
    _timerRunning = true;
    _timerPaused = false;
    _lastPersonSeen = null;
    _alerted = false;
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    notifyListeners();
  }

  void pauseTimer() {
    if (!_timerRunning || _timerPaused) return;
    _timerPaused = true;
    notifyListeners();
  }

  void resumeTimer() {
    if (!_timerRunning || !_timerPaused) return;
    _timerPaused = false;
    _lastPersonSeen = null;
    notifyListeners();
  }

  void stopTimer() {
    _timerTick?.cancel();
    _timerRunning = false;
    _timerPaused = false;
    _remainingSeconds = 0;
    _alerted = false;
    notifyListeners();
  }

  void _onTick() {
    if (!_timerRunning || _timerPaused) {
      notifyListeners();
      return;
    }
    if (_remainingSeconds > 0) {
      _remainingSeconds--;
    }
    if (_remainingSeconds <= 0) {
      stopTimer();
    }
    notifyListeners();
  }

  // --- Detección ---

  void setCameraActive(bool active) {
    if (_cameraActive == active) return;
    _cameraActive = active;
    notifyListeners();
  }

  void setConfidence(double value) {
    _confidence = value.clamp(0.2, 0.9).toDouble();
    notifyListeners();
  }

  void setNoPersonAlertSeconds(int seconds) {
    _noPersonAlertSeconds = seconds.clamp(10, 120).toInt();
    notifyListeners();
  }

  void setDangerMinutes(int minutes) {
    _dangerMinutes = minutes.clamp(1, 60).toInt();
    notifyListeners();
  }

  /// Actualiza el resultado de detección de personas desde el detector.
  void onPersonDetected(int count) {
    final wasPresent = _personPresent;
    _personPresent = count > 0;
    if (_personPresent) {
      _lastPersonSeen = DateTime.now();
      _alerted = false;
    }
    notifyListeners();
  }

  /// Devuelve True si debe emitir alarma por cocina desatendida.
  bool shouldAlert() {
    if (!_timerRunning || _timerPaused) return false;
    if (_personPresent) return false;
    if (_lastPersonSeen == null) {
      // Nunca se vio una persona durante este plazo.
      return !_alerted && _remainingSeconds > 0;
    }
    final elapsed = DateTime.now().difference(_lastPersonSeen!).inSeconds;
    return !_alerted && elapsed >= _noPersonAlertSeconds;
  }

  String get statusText {
    if (!_timerRunning) {
      return _mode == AppMode.standalone
          ? "Inicia el tiempo de monitoreo"
          : "Conectado al PC";
    }
    if (_timerPaused) return "Monitoreo en PAUSA";
    if (!_cameraActive) return "Iniciando cámara...";
    if (_personPresent) return "Persona detectada - cocina atendida";
    return "SIN PERSONA DETECTADA";
  }

  void onTimerExpired() {
    _alerted = true;
    _alerts.insert(
      0,
      StandaloneAlert(
        "Cocina desatendida: no se detectó persona en el plazo de monitoreo",
        DateTime.now(),
      ),
    );
    if (_alerts.length > 50) _alerts.removeLast();
    notifyListeners();
  }

  void triggerAlert(String message) {
    _alerted = true;
    _alerts.insert(0, StandaloneAlert(message, DateTime.now()));
    if (_alerts.length > 50) _alerts.removeLast();
    notifyListeners();
  }

  String get remainingLabel {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    super.dispose();
  }
}
