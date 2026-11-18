import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/remote_cloud_service.dart';

Future<RemoteCloudCredentials?> showRemoteCloudPairingDialog(
  BuildContext context, {
  required String language,
}) {
  return showDialog<RemoteCloudCredentials>(
    context: context,
    builder: (_) => _RemoteCloudPairingDialog(english: language == 'en'),
  );
}

class _RemoteCloudPairingDialog extends StatefulWidget {
  final bool english;

  const _RemoteCloudPairingDialog({required this.english});

  @override
  State<_RemoteCloudPairingDialog> createState() =>
      _RemoteCloudPairingDialogState();
}

class _RemoteCloudPairingDialogState extends State<_RemoteCloudPairingDialog> {
  bool _handled = false;
  String? _error;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final rawValue = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (rawValue == null) return;
    try {
      final credentials = RemoteCloudCredentials.fromInvite(rawValue);
      _handled = true;
      Navigator.of(context).pop(credentials);
    } on FormatException catch (error) {
      setState(() => _error = error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = widget.english;
    return AlertDialog(
      title: Text(english ? 'Pair with CocinaP PC' : 'Vincular con CocinaP PC'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              english
                  ? 'Scan the pairing QR shown by CocinaP on the home PC.'
                  : 'Escanea el código QR de vinculación que muestra CocinaP en la PC de casa.',
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(onDetect: _onDetect),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(english ? 'Cancel' : 'Cancelar'),
        ),
      ],
    );
  }
}
