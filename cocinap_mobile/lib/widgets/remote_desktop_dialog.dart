import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/remote_desktop_service.dart';

class RemoteDesktopConfig {
  final String baseUrl;
  final String apiKey;

  const RemoteDesktopConfig({
    required this.baseUrl,
    required this.apiKey,
  });
}

Future<RemoteDesktopConfig?> showRemoteDesktopDialog(
  BuildContext context, {
  required String language,
  String initialBaseUrl = '',
  String initialApiKey = '',
}) {
  return showDialog<RemoteDesktopConfig>(
    context: context,
    builder: (_) => _RemoteDesktopDialog(
      english: language == 'en',
      initialBaseUrl: initialBaseUrl,
      initialApiKey: initialApiKey,
    ),
  );
}

class _RemoteDesktopDialog extends StatefulWidget {
  final bool english;
  final String initialBaseUrl;
  final String initialApiKey;

  const _RemoteDesktopDialog({
    required this.english,
    required this.initialBaseUrl,
    required this.initialApiKey,
  });

  @override
  State<_RemoteDesktopDialog> createState() => _RemoteDesktopDialogState();
}

class _RemoteDesktopDialogState extends State<_RemoteDesktopDialog> {
  late final _urlController =
      TextEditingController(text: widget.initialBaseUrl);
  late final _keyController = TextEditingController(text: widget.initialApiKey);
  final _service = RemoteDesktopService();
  bool _checking = false;
  bool _verified = false;
  bool _cameraAvailable = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  String _failureMessage(Object error) {
    if (error is FormatException) return error.message.toString();
    if (error is HttpException) return error.message;
    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException) {
      return widget.english
          ? 'Could not reach the PC. Check Tailscale on both devices and try again.'
          : 'No se pudo conectar con la PC. Comprueba Tailscale en ambos dispositivos e inténtalo de nuevo.';
    }
    return widget.english
        ? 'Could not verify the desktop connection.'
        : 'No se pudo verificar la conexión con la PC.';
  }

  Future<void> _verify() async {
    setState(() {
      _checking = true;
      _verified = false;
      _error = null;
    });
    try {
      final cameraAvailable = await _service.verifyConnection(
        baseUrl: _urlController.text,
        apiKey: _keyController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _verified = true;
          _cameraAvailable = cameraAvailable;
        });
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = _failureMessage(error));
    } on HttpException catch (error) {
      if (mounted) setState(() => _error = _failureMessage(error));
    } on SocketException catch (error) {
      if (mounted) setState(() => _error = _failureMessage(error));
    } on TimeoutException catch (error) {
      if (mounted) setState(() => _error = _failureMessage(error));
    } on HandshakeException catch (error) {
      if (mounted) setState(() => _error = _failureMessage(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = widget.english;
    return AlertDialog(
      title: Text(english
          ? 'Connect to CocinaP Desktop'
          : 'Conectar a CocinaP Escritorio'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                english
                    ? 'Install Tailscale on the PC and phone, sign in to the same tailnet, then enable Tailscale Serve on the PC. Do not expose port 8080 or use Tailscale Funnel.'
                    : 'Instala Tailscale en la PC y el teléfono e inicia sesión en la misma red privada. Luego activa Tailscale Serve en la PC. No expongas el puerto 8080 ni uses Tailscale Funnel.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (_) => setState(() {
                  _verified = false;
                  _error = null;
                }),
                decoration: InputDecoration(
                  labelText: english
                      ? 'Tailscale Serve HTTPS address'
                      : 'Dirección HTTPS de Tailscale Serve',
                  hintText: 'https://pc-name.tailnet.ts.net',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _keyController,
                obscureText: true,
                autocorrect: false,
                onChanged: (_) => setState(() {
                  _verified = false;
                  _error = null;
                }),
                decoration: InputDecoration(
                  labelText:
                      english ? 'CocinaP API key' : 'Clave API de CocinaP',
                  helperText: english
                      ? 'Copy it from the desktop connection window.'
                      : 'Cópiala desde la ventana de conexión de la PC.',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_verified) ...[
                const SizedBox(height: 8),
                Text(
                  _cameraAvailable
                      ? (english
                          ? 'Connection and camera verified. The PC must stay on and monitoring must be started there.'
                          : 'Conexión y cámara verificadas. La PC debe permanecer encendida y el monitoreo debe iniciarse allí.')
                      : (english
                          ? 'PC connection verified, but no camera is online yet. You can save this connection and check the desktop camera.'
                          : 'Conexión con la PC verificada, pero no hay una cámara activa. Puedes guardar la conexión y revisar la cámara de escritorio.'),
                  style: TextStyle(
                    color: _cameraAvailable
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(english ? 'Cancel' : 'Cancelar'),
        ),
        OutlinedButton(
          onPressed: _checking ? null : _verify,
          child: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(english ? 'Test connection' : 'Probar conexión'),
        ),
        FilledButton(
          onPressed: _verified
              ? () => Navigator.pop(
                    context,
                    RemoteDesktopConfig(
                      baseUrl: RemoteDesktopService.parseBaseUrl(
                        _urlController.text,
                      ).toString(),
                      apiKey: _keyController.text.trim(),
                    ),
                  )
              : null,
          child: Text(english ? 'Connect' : 'Conectar'),
        ),
      ],
    );
  }
}
