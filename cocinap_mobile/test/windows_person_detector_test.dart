import 'package:cocinap_mobile/services/windows_person_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MoveNet keypoints produce a person box when core points are visible',
      () {
    final values = List<num>.filled(17 * 3, 0.1);
    for (final index in [0, 5, 6, 11, 12]) {
      values[index * 3] = 0.25 + index / 100;
      values[index * 3 + 1] = 0.3 + index / 100;
      values[index * 3 + 2] = 0.9;
    }

    final result = parseMoveNetOutput(values, confidence: 0.5);

    expect(result.count, 1);
    expect(result.maxScore, closeTo(0.9, 0.001));
    expect(result.boxes, hasLength(1));
    expect(result.boxes.single.label, 'person');
  });

  test('MoveNet does not report a person when core landmarks are weak', () {
    final result = parseMoveNetOutput(
      List<num>.filled(17 * 3, 0.1),
      confidence: 0.5,
    );

    expect(result.count, 0);
    expect(result.boxes, isEmpty);
  });

  test('MoveNet rejects unexpected output dimensions', () {
    expect(
      () => parseMoveNetOutput([0, 0, 0], confidence: 0.5),
      throwsFormatException,
    );
  });
}
