import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// Detector de personas on-device usando TFLite.
///
/// Carga el modelo MobileNetV2-SSD (COCO) que distingue 90 clases.
/// La clase 0 es "background", la clase 1 es "person".
/// Las detecciones se filtran por confianza y clase "person".
class PersonDetector {
  Interpreter? _interpreter;
  bool _loaded = false;

  // Entrada del modelo: 300x300 RGB
  static const int _inputSize = 300;

  // El modelo devuelve 4 outputs (SSD MobileNet):
  // [1, 10, num] boxes, classes, scores, [num] detections
  late List<List<double>> _boxes;
  late List<List<double>> _classes;
  late List<List<double>> _scores;
  late List<double> _numDetections;

  /// Carga el .tflite desde assets a una ubicación temporal.
  Future<void> load(String assetPath) async {
    if (_loaded) return;

    // Copiar el asset a un archivo temporal accesible.
    final data = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/person_detector.tflite');
    await file.writeAsBytes(data.buffer.asUint8List());

    final options = InterpreterOptions()..threads = 1;
    _interpreter = Interpreter.fromFile(file, options: options);

    _boxes = List.generate(1, (_) => List.filled(10, 0.0));
    _classes = List.generate(1, (_) => List.filled(10, 0.0));
    _scores = List.generate(1, (_) => List.filled(10, 0.0));
    _numDetections = List.filled(1, 0.0);

    _loaded = true;
  }

  /// Detecta personas en una imagen RGBA/JPEG.
  /// Devuelve el número de personas detectadas.
  Future<int> detectPerson(img.Image image, {double confidence = 0.5}) async {
    if (!_loaded || _interpreter == null) return 0;

    // Redimensionar a la entrada del modelo (300x300, mantener proporción crop).
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);

    // Normalizar a [0,1] float32.
    final input = Float32List(1 * _inputSize * _inputSize * 3);
    var idx = 0;
    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final p = resized.getPixel(x, y);
        input[idx++] = p.r.toDouble() / 255.0;
        input[idx++] = p.g.toDouble() / 255.0;
        input[idx++] = p.b.toDouble() / 255.0;
      }
    }

    final boxes = List.generate(1, (_) => List<double>.filled(10, 0));
    final classes = List.generate(1, (_) => List<double>.filled(10, 0));
    final scores = List.generate(1, (_) => List<double>.filled(10, 0));
    final detections = List<double>.filled(1, 0);

    _interpreter!.runForMultipleInputs(
      [input],
      {
        0: boxes,
        1: classes,
        2: scores,
        3: detections,
      },
    );

    var people = 0;
    final num = (detections[0]).round();
    for (var i = 0; i < num && i < 10; i++) {
      final cls = classes[0][i].round();
      final score = scores[0][i];
      // COCO: clase 1 = person
      if (cls == 1 && score >= confidence) {
        people++;
      }
    }
    return people;
  }

  bool get loaded => _loaded;

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _loaded = false;
  }
}
