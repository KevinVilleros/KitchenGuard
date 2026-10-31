import 'package:cocinap_mobile/widgets/camera_url_dialog.dart';
import 'package:cocinap_mobile/services/onvif_camera_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stream2 fallback uses the discovered camera address', () {
    final camera = OnvifCamera(
      name: 'Camera',
      address: '192.168.1.46',
      deviceService: Uri.parse('http://192.168.1.46/onvif/device_service'),
    );

    expect(
      buildStream2FallbackUri(camera),
      Uri.parse('rtsp://192.168.1.46:554/stream2'),
    );
  });

  testWidgets('Canceling the camera URL dialog closes cleanly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCameraUrlDialog(
                context,
                currentUrl: '',
                language: 'es',
              ),
              child: const Text('Open camera settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open camera settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Conectar una cámara IP'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manual RTSP URL is returned from the dialog',
      (WidgetTester tester) async {
    Future<String?>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = showCameraUrlDialog(
                  context,
                  currentUrl: '',
                  language: 'es',
                );
              },
              child: const Text('Open camera settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open camera settings'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'rtsp://192.168.1.56:554/stream',
    );
    await tester.tap(find.text('Guardar y conectar'));
    await tester.pumpAndSettle();

    expect(await result, 'rtsp://192.168.1.56:554/stream');
    expect(tester.takeException(), isNull);
  });
}
