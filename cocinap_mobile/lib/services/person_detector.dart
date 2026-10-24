import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;

/// Una caja detectada, con coordenadas normalizadas [0,1] sobre la imagen de
/// entrada.
class DetectedBox {
  final double top;
  final double left;
  final double bottom;
  final double right;
  final double score;
  final int classId;
  final String label;

  const DetectedBox({
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
    required this.score,
    required this.classId,
    required this.label,
  });
}

/// Resultado de una inferencia de detección de personas.
class DetectionResult {
  /// Número de personas detectadas.
  final int count;

  /// Máxima puntuación de confianza de las personas detectadas.
  final double maxScore;

  /// Todas las detecciones (para depuración).
  final List<DetectedBox> boxes;

  const DetectionResult(this.count, this.maxScore, [this.boxes = const []]);

  static const DetectionResult empty = DetectionResult(0, 0);
}

/// Detector de personas on-device usando **Google ML Kit Pose Detection**.
///
/// A diferencia de un detector de objetos genérico (que solo clasifica en
/// categorías amplias como "home goods" y NO reconoce "persona"), el detector
/// de poses solo devuelve un resultado cuando **detecta el cuerpo humano**
/// (33 puntos: nariz, hombros, caderas, rodillas...). Por eso no confunde
/// objetos con personas: si no hay un cuerpo real, no hay pose.
class PersonDetector {
  PoseDetector? _detector;
  bool _loaded = false;

  /// Puntos clave que usamos para estimar la confianza de que hay una persona.
  static const List<PoseLandmarkType> _coreLandmarks = [
    PoseLandmarkType.nose,
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
  ];

  int _dbgCounter = 0;

  /// Crea el detector de poses de ML Kit.
  Future<void> load(String assetPath) async {
    if (_loaded) return;
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
    _loaded = true;
    debugPrint('PD ML Kit PoseDetector listo');
  }

  /// Detecta personas en un frame JPEG (cámaras IP MJPEG o foto).
  Future<DetectionResult> detectFromJpeg(
    Uint8List jpeg, {
    double confidence = 0.5,
  }) async {
    if (!_loaded || _detector == null) return DetectionResult.empty;
    try {
      final image = img.decodeJpg(jpeg);
      if (image == null) return DetectionResult.empty;
      final nv21 = _imageToNv21(image);
      final input = _inputFromNv21(nv21, image.width, image.height, 0);
      return await _process(input, confidence);
    } catch (e) {
      debugPrint('PD jpeg error: $e');
      return DetectionResult.empty;
    }
  }

  /// Detecta personas en una imagen ya decodificada (RGB).
  Future<DetectionResult> detectPerson(
    img.Image image, {
    double confidence = 0.5,
  }) async {
    if (!_loaded || _detector == null) return DetectionResult.empty;
    try {
      final nv21 = _imageToNv21(image);
      final input = _inputFromNv21(nv21, image.width, image.height, 0);
      return await _process(input, confidence);
    } catch (e) {
      debugPrint('PD person error: $e');
      return DetectionResult.empty;
    }
  }

  /// Detecta personas directamente desde un frame de la cámara del móvil.
  Future<DetectionResult> detectFromCameraImage(
    CameraImage image, {
    int rotationDegrees = 0,
    double confidence = 0.5,
  }) async {
    if (!_loaded || _detector == null) return DetectionResult.empty;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final input = _inputFromIosBgra(image);
        if (input == null) return DetectionResult.empty;
        return await _process(input, confidence);
      }

      final nv21 = _cameraImageToNv21(image);
      if (nv21 == null) return DetectionResult.empty;
      final input =
          _inputFromNv21(nv21, image.width, image.height, rotationDegrees);
      return await _process(input, confidence);
    } catch (e) {
      debugPrint('PD camera error: $e');
      return DetectionResult.empty;
    }
  }

  Future<DetectionResult> _process(
    InputImage input,
    double confidence,
  ) async {
    final poses = await _detector!.processImage(input);
    var people = 0;
    var maxScore = 0.0;
    final boxes = <DetectedBox>[];

    final size = input.metadata?.size;
    final w = (size?.width ?? 0).toDouble();
    final h = (size?.height ?? 0).toDouble();

    _dbgCounter++;
    final dbg = _dbgCounter % 10 == 0;

    for (final pose in poses) {
      final landmarks = pose.landmarks;
      if (landmarks.isEmpty) continue;

      // Caja envolvente de los puntos con buena visibilidad.
      var minX = double.infinity, minY = double.infinity;
      var maxX = -double.infinity, maxY = -double.infinity;
      for (final lm in landmarks.values) {
        if (lm.likelihood < 0.3) continue;
        if (lm.x < minX) minX = lm.x;
        if (lm.y < minY) minY = lm.y;
        if (lm.x > maxX) maxX = lm.x;
        if (lm.y > maxY) maxY = lm.y;
      }
      if (!minX.isFinite || !minY.isFinite) continue;

      // Confianza = promedio de visibilidad de los puntos clave del cuerpo.
      var sum = 0.0;
      var n = 0;
      for (final type in _coreLandmarks) {
        final lm = landmarks[type];
        if (lm == null) continue;
        sum += lm.likelihood;
        n++;
      }
      final score = n == 0 ? 0.0 : sum / n;
      final accepted = score >= confidence;

      if (dbg) {
        debugPrint('PD pose score=${score.toStringAsFixed(2)} '
            'landmarks=${landmarks.length} ${accepted ? 'person' : 'reject'}');
      }

      boxes.add(DetectedBox(
        top: (h <= 0 ? minY : minY / h).clamp(0.0, 1.0).toDouble(),
        left: (w <= 0 ? minX : minX / w).clamp(0.0, 1.0).toDouble(),
        bottom: (h <= 0 ? maxY : maxY / h).clamp(0.0, 1.0).toDouble(),
        right: (w <= 0 ? maxX : maxX / w).clamp(0.0, 1.0).toDouble(),
        score: score,
        classId: 0,
        label: 'person',
      ));

      if (accepted) {
        people++;
        if (score > maxScore) maxScore = score;
      }
    }

    if (dbg || poses.isEmpty) {
      debugPrint('PD detect poses=${poses.length} people=$people '
          'max=${maxScore.toStringAsFixed(2)}');
    }
    return DetectionResult(people, maxScore, boxes);
  }

  /// Convierte un [CameraImage] (YUV420 planar / NV21 / BGRA) a un buffer
  /// NV21 contiguo entendible por ML Kit.
  Uint8List? _cameraImageToNv21(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      final group = image.format.group;

      if (group == ImageFormatGroup.yuv420 ||
          group == ImageFormatGroup.nv21) {
        if (image.planes.isEmpty) return null;
        final yPlane = image.planes[0];
        final nv21 = Uint8List(width * height + width * height ~/ 2);

        var pos = 0;
        for (var y = 0; y < height; y++) {
          final rowStart = y * yPlane.bytesPerRow;
          final rowEnd = rowStart + width;
          if (rowEnd > yPlane.bytes.length) return null;
          nv21.setRange(pos, pos + width, yPlane.bytes, rowStart);
          pos += width;
        }

        if (image.planes.length == 1) return null;

        final uvPlane = image.planes[1];
        final uvRowStride = uvPlane.bytesPerRow;
        final uvPixelStride = uvPlane.bytesPerPixel ?? 1;
        if (uvPixelStride <= 0) return null;

        if (image.planes.length == 2) {
          // NV21: plano único intercalado VU.
          for (var y = 0; y < height ~/ 2; y++) {
            final rowStart = y * uvRowStride;
            for (var x = 0; x < width ~/ 2; x++) {
              final vuIndex = rowStart + x * uvPixelStride;
              if (vuIndex + 1 >= uvPlane.bytes.length) return null;
              nv21[pos++] = uvPlane.bytes[vuIndex]; // V
              nv21[pos++] = uvPlane.bytes[vuIndex + 1]; // U
            }
          }
          return nv21;
        }

        final uPlane = image.planes[1];
        final vPlane = image.planes[2];
        final uRowStride = uPlane.bytesPerRow;
        final vRowStride = vPlane.bytesPerRow;
        final uPixelStride = uPlane.bytesPerPixel ?? 1;
        final vPixelStride = vPlane.bytesPerPixel ?? 1;
        for (var y = 0; y < height ~/ 2; y++) {
          for (var x = 0; x < width ~/ 2; x++) {
            final uIndex = y * uRowStride + x * uPixelStride;
            final vIndex = y * vRowStride + x * vPixelStride;
            if (vIndex >= vPlane.bytes.length || uIndex >= uPlane.bytes.length) {
              return null;
            }
            nv21[pos++] = vPlane.bytes[vIndex]; // V
            nv21[pos++] = uPlane.bytes[uIndex]; // U
          }
        }
        return nv21;
      }

      if (group == ImageFormatGroup.bgra8888) {
        final plane = image.planes[0];
        final bgra = plane.bytes;
        final rgbImage = img.Image(width: width, height: height);
        for (var y = 0; y < height; y++) {
          final rowStart = y * plane.bytesPerRow;
          for (var x = 0; x < width; x++) {
            final idx = rowStart + x * 4;
            if (idx + 2 >= bgra.length) return null;
            rgbImage.setPixelRgb(x, y, bgra[idx + 2], bgra[idx + 1], bgra[idx]);
          }
        }
        return _imageToNv21(rgbImage);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Convierte una imagen RGB de `package:image` a NV21.
  Uint8List _imageToNv21(img.Image image) {
    final width = image.width;
    final height = image.height;
    final nv21 = Uint8List(width * height + width * height ~/ 2);

    var yPos = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final yy = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
        nv21[yPos++] = yy;
      }
    }

    var uvPos = width * height;
    for (var y = 0; y < height; y += 2) {
      for (var x = 0; x < width; x += 2) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final u = (-0.169 * r - 0.331 * g + 0.5 * b + 128)
            .round()
            .clamp(0, 255);
        final v = (0.5 * r - 0.419 * g - 0.081 * b + 128)
            .round()
            .clamp(0, 255);
        nv21[uvPos++] = v; // V primero (NV21)
        nv21[uvPos++] = u;
      }
    }
    return nv21;
  }

  InputImage? _inputFromIosBgra(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;
    if (plane.bytes.isEmpty || plane.bytesPerRow <= 0) return null;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImage _inputFromNv21(
    Uint8List nv21,
    int width,
    int height,
    int rotationDegrees,
  ) {
    final rotation = InputImageRotationValue.fromRawValue(rotationDegrees) ??
        InputImageRotation.rotation0deg;
    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: ui.Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width,
      ),
    );
  }

  bool get loaded => _loaded;

  /// Descripción del estado del detector (para diagnóstico en pantalla).
  String get debugInfo => 'ML Kit Pose · cuerpo (33 puntos)';

  void dispose() {
    _detector?.close();
    _detector = null;
    _loaded = false;
  }
}
