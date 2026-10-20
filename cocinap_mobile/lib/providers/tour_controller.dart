import 'package:flutter/foundation.dart';
import '../content/content.dart';

/// Controla el tour guiado de la interfaz (coach marks).
class TourController extends ChangeNotifier {
  bool _active = false;
  int _step = 0;

  bool get active => _active;
  int get step => _step;
  int get totalSteps => AppTour.totalSteps;

  /// Pestaña que debe resaltarse en el paso actual, o null si es una tarjeta
  /// central (paso de bienvenida).
  int? get highlightedTab => _step == 0 ? null : _step - 1;

  void start() {
    _active = true;
    _step = 0;
    notifyListeners();
  }

  void next() {
    if (_step >= totalSteps - 1) {
      end();
    } else {
      _step++;
      notifyListeners();
    }
  }

  void prev() {
    if (_step > 0) {
      _step--;
      notifyListeners();
    }
  }

  void end() {
    if (!_active) return;
    _active = false;
    notifyListeners();
  }
}
