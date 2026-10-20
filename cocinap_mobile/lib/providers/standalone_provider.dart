import 'dart:async';
import 'package:flutter/foundation.dart';

/// Fuente de video del modo independiente.
enum StandaloneCameraSource {
  /// Cámara integrada / USB del propio móvil.
  phone,
  /// Cámara IP del hogar o de seguridad vía stream HTTP/MJPEG.
  ipCamera,
}

/// Resultado de una alerta por cocina desatendida.
class StandaloneAlert {
  final String message;
  final DateTime time;
  const StandaloneAlert(this.message, this.time);
}

/// Proveedor del modo standalone: monitoreo con cámara del móvil o cámara IP,
/// temporizador configurable y alertas si no hay persona en la cocina.
class StandaloneProvider extends ChangeNotifier {
  StandaloneCameraSource _cameraSource = StandaloneCameraSource.phone;
  String _cameraUrl = "";

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

  // Referencia para medir cuánto tiempo lleva la cocina sin persona:
  // el último momento en que se vio a alguien, o el inicio del monitoreo.
  DateTime? _timerStartedAt;

  // Momento del último aviso emitido (para repetir solo cada cierto tiempo).
  DateTime? _lastAlertAt;

  // --- Configuración ---
  double _confidence = 0.5;
  int _noPersonAlertSeconds = 30; // alerta si no hay persona este tiempo

  // Alerta se dispara si pasa este tiempo SEGUIDO sin persona (configurable)
  int _dangerMinutes = 5; // tiempo peligroso sin atender la cocina

  final List<StandaloneAlert> _alerts = [];
  bool _alerted = false;

  StandaloneCameraSource get cameraSource => _cameraSource;
  String get cameraUrl => _cameraUrl;
  int get durationMinutes => _durationMinutes;
  int get remainingSeconds => _remainingSeconds;
  bool get timerRunning => _timerRunning;
  bool get timerPaused => _timerPaused;
  bool get personPresent => _personPresent;
  bool get cameraActive => _cameraActive;

  /// Segundos transcurridos sin detectar persona (desde la última detección o
  /// desde el inicio del monitoreo).
  int get absenceSeconds {
    final ref = _lastPersonSeen ?? _timerStartedAt;
    if (ref == null) return 0;
    return DateTime.now().difference(ref).inSeconds;
  }
  double get confidence => _confidence;
  int get noPersonAlertSeconds => _noPersonAlertSeconds;
  int get dangerMinutes => _dangerMinutes;
  List<StandaloneAlert> get alerts => _alerts;

  String get cameraSourceLabel => switch (_cameraSource) {
        StandaloneCameraSource.phone =>
            "Cámara del móvil",
        StandaloneCameraSource.ipCamera =>
            "Cámara IP (hogar/seguridad)",
      };

  void setCameraSource(StandaloneCameraSource source) {
    if (_cameraSource == source) return;
    _cameraSource = source;
    notifyListeners();
  }

  void setCameraUrl(String url) {
    _cameraUrl = url.trim();
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
    _timerStartedAt = DateTime.now();
    _lastAlertAt = null;
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
    _timerStartedAt = DateTime.now();
    _lastAlertAt = null;
    _alerted = false;
    notifyListeners();
  }

  void stopTimer() {
    _timerTick?.cancel();
    _timerRunning = false;
    _timerPaused = false;
    _remainingSeconds = 0;
    _alerted = false;
    _lastAlertAt = null;
    _timerStartedAt = null;
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
    _personPresent = count > 0;
    if (_personPresent) {
      _lastPersonSeen = DateTime.now();
      _alerted = false;
      _lastAlertAt = null;
    }
    notifyListeners();
  }

  /// Devuelve True si debe emitir alarma por cocina desatendida.
  ///
  /// Se espera el tiempo configurado ([noPersonAlertSeconds]) desde la última
  /// vez que se vio a una persona (o desde el inicio del monitoreo) y, una vez
  /// emitido, se repite el aviso cada ese mismo intervalo mientras la cocina
  /// siga desatendida.
  bool shouldAlert() {
    if (!_timerRunning || _timerPaused) return false;
    if (_personPresent) return false;
    if (absenceSeconds < _noPersonAlertSeconds) return false;
    if (!_alerted) return true;
    final last = _lastAlertAt;
    if (last == null) return true;
    return DateTime.now().difference(last).inSeconds >= _noPersonAlertSeconds;
  }

  String get statusText {
    if (!_timerRunning) return "Inicia el tiempo de monitoreo";
    if (_timerPaused) return "Monitoreo en PAUSA";
    if (!_cameraActive) return "Iniciando cámara...";
    if (_personPresent) return "Persona detectada - cocina atendida";
    return "SIN PERSONA DETECTADA (${absenceSeconds}s)";
  }

  void triggerAlert(String message) {
    _alerted = true;
    _lastAlertAt = DateTime.now();
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
