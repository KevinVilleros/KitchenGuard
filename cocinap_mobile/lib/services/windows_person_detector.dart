import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import 'detection_result.dart';

const _inputSize = 192;
const _landmarkCount = 17;
const _valuesPerLandmark = 3;
const _coreLandmarks = [0, 5, 6, 11, 12];

@visibleForTesting
DetectionResult parseMoveNetOutput(
  List<num> values, {
  required double confidence,
}) {
  if (values.length != _landmarkCount * _valuesPerLandmark) {
    throw FormatException(
      'MoveNet returned ${values.length} values; expected '
      '${_landmarkCount * _valuesPerLandmark}.',
    );
  }

  final landmarks = <({double x, double y, double score})>[];
  for (var index = 0; index < _landmarkCount; index++) {
    final offset = index * _valuesPerLandmark;
    landmarks.add((
      y: values[offset].toDouble().clamp(0, 1).toDouble(),
      x: values[offset + 1].toDouble().clamp(0, 1).toDouble(),
      score: values[offset + 2].toDouble().clamp(0, 1).toDouble(),
    ));
  }

  final coreScores = _coreLandmarks
      .map((index) => landmarks[index].score)
      .where((score) => score >= 0.3)
      .toList();
  if (coreScores.length < 3) return DetectionResult.empty;

  final score = coreScores.reduce((a, b) => a + b) / coreScores.length;
  final visibleLandmarks =
      landmarks.where((landmark) => landmark.score >= 0.3).toList();
  if (visibleLandmarks.isEmpty) return DetectionResult.empty;

  final box = DetectedBox(
    top: visibleLandmarks.map((landmark) => landmark.y).reduce(_min),
    left: visibleLandmarks.map((landmark) => landmark.x).reduce(_min),
    bottom: visibleLandmarks.map((landmark) => landmark.y).reduce(_max),
    right: visibleLandmarks.map((landmark) => landmark.x).reduce(_max),
    score: score,
    classId: 0,
    label: 'person',
  );
  return DetectionResult(score >= confidence ? 1 : 0, score, [box]);
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;

class WindowsPersonDetector {
  final OnnxRuntime _runtime = OnnxRuntime();
  OrtSession? _session;

  bool get loaded => _session != null;

  Future<void> load() async {
    _session ??= await _runtime.createSessionFromAsset(
      'assets/models/movenet_lightning.onnx',
      options: OrtSessionOptions(
        intraOpNumThreads: 2,
        interOpNumThreads: 1,
        providers: [OrtProvider.CPU],
      ),
    );

    if (!_session!.inputNames.contains('pixel_values') ||
        !_session!.outputNames.contains('keypoints')) {
      await _session!.close();
      _session = null;
      throw const FormatException('Unexpected MoveNet model tensor names.');
    }
  }

  Future<DetectionResult> detectJpeg(
    Uint8List jpeg, {
    required double confidence,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError('Windows person detector has not been loaded.');
    }

    final decoded = img.decodeImage(jpeg);
    if (decoded == null) throw const FormatException('Invalid camera JPEG.');
    final resized = img.copyResize(
      decoded,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );
    final rgba = Uint8List(_inputSize * _inputSize * 4);
    var offset = 0;
    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        rgba[offset++] = pixel.r.toInt();
        rgba[offset++] = pixel.g.toInt();
        rgba[offset++] = pixel.b.toInt();
        rgba[offset++] = 255;
      }
    }

    final input = await OrtValue.fromList(
      rgba,
      [1, _inputSize, _inputSize, 4],
    );
    try {
      final outputs = await session.run({'pixel_values': input});
      try {
        final output = outputs['keypoints'];
        if (output == null) {
          throw const FormatException('MoveNet did not return keypoints.');
        }
        final flattened = await output.asFlattenedList();
        return parseMoveNetOutput(
          flattened.cast<num>(),
          confidence: confidence,
        );
      } finally {
        for (final value in outputs.values) {
          await value.dispose();
        }
      }
    } finally {
      await input.dispose();
    }
  }

  Future<void> dispose() async {
    final session = _session;
    _session = null;
    await session?.close();
  }
}
