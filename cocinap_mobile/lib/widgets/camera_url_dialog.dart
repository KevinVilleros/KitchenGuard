import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import '../services/onvif_camera_service.dart';

String cameraUrlDisplayLabel(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return value;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port${uri.path}';
}

Future<String?> showCameraUrlDialog(
  BuildContext context, {
  required String currentUrl,
  required String language,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CameraUrlDialog(
      currentUrl: currentUrl,
      english: language == 'en',
    ),
  );
}

@visibleForTesting
Uri buildStream2FallbackUri(OnvifCamera camera) => Uri(
      scheme: 'rtsp',
      host: camera.address,
      port: 554,
      path: '/stream2',
    );

class _CameraUrlDialog extends StatefulWidget {
  final String currentUrl;
  final bool english;

  const _CameraUrlDialog({
    required this.currentUrl,
    required this.english,
  });

  @override
  State<_CameraUrlDialog> createState() => _CameraUrlDialogState();
}

class _CameraUrlDialogState extends State<_CameraUrlDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.currentUrl);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final english = widget.english;
    return AlertDialog(
      title: Text(english ? 'Connect an IP camera' : 'Conectar una cámara IP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            english
                ? 'Search for ONVIF cameras on your Wi-Fi, or enter a camera stream URL. HTTP/MJPEG and RTSP are supported; an IP address alone may not be enough.'
                : 'Busca cámaras ONVIF en tu Wi-Fi o escribe la URL del stream. Se admiten HTTP/MJPEG y RTSP; la dirección IP sola puede no bastar.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final discoveredUrl = await _showOnvifCameraDialog(
                context,
                english: english,
              );
              if (discoveredUrl != null && context.mounted) {
                Navigator.pop(context, discoveredUrl);
              }
            },
            icon: const Icon(Icons.wifi_find),
            label: Text(
              english
                  ? 'Find cameras on this Wi-Fi'
                  : 'Buscar cámaras en este Wi-Fi',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: english ? 'Camera stream URL' : 'URL del stream',
              hintText: 'rtsp://192.168.1.60:554/stream',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            english
                ? 'If the camera is not discovered, check that your phone and camera use the same Wi-Fi. Use a changed camera password, not its factory default.'
                : 'Si no aparece, comprueba que el teléfono y la cámara estén en el mismo Wi-Fi. Usa una contraseña propia, no la predeterminada de fábrica.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(english ? 'Cancel' : 'Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            final uri = Uri.tryParse(value);
            if (uri == null ||
                !uri.hasAuthority ||
                uri.host.isEmpty ||
                !{'http', 'https', 'rtsp'}.contains(uri.scheme.toLowerCase())) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    english
                        ? 'Enter a valid http://, https://, or rtsp:// stream URL.'
                        : 'Escribe una URL válida que comience con http://, https:// o rtsp://.',
                  ),
                ),
              );
              return;
            }
            Navigator.pop(context, uri.toString());
          },
          child: Text(english ? 'Save and connect' : 'Guardar y conectar'),
        ),
      ],
    );
  }
}

Future<String?> _showOnvifCameraDialog(
  BuildContext context, {
  required bool english,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _OnvifCameraDialog(english: english),
  );
}

class _OnvifCameraDialog extends StatefulWidget {
  final bool english;

  const _OnvifCameraDialog({required this.english});

  @override
  State<_OnvifCameraDialog> createState() => _OnvifCameraDialogState();
}

class _OnvifCameraDialogState extends State<_OnvifCameraDialog> {
  final _service = OnvifCameraService();
  List<OnvifCamera> _cameras = const [];
  bool _searching = true;
  String? _error;
  OnvifCamera? _failedCamera;
  (String, String)? _failedCredentials;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
      _cameras = const [];
    });
    try {
      final cameras = await _service.discover();
      if (!mounted) return;
      setState(() {
        _cameras = cameras;
        _searching = false;
      });
    } on SocketException {
      _showSearchError();
    } on TimeoutException {
      _showSearchError();
    } on PlatformException {
      _showSearchError();
    } on FormatException {
      _showSearchError();
    } on XmlException {
      _showSearchError();
    } on UnsupportedError {
      _showSearchError();
    } catch (error) {
      debugPrint('ONVIF discovery failed: ${error.runtimeType}');
      _showSearchError();
    }
  }

  Future<void> _connect(OnvifCamera camera) async {
    final credentials = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _OnvifCredentialsDialog(english: widget.english),
    );
    if (credentials == null || !mounted) return;

    setState(() {
      _searching = true;
      _error = null;
      _failedCamera = camera;
      _failedCredentials = credentials;
    });
    try {
      final streamUri = await _service.getStreamUri(
        camera,
        username: credentials.$1,
        password: credentials.$2,
      );
      if (mounted) Navigator.pop(context, streamUri.toString());
    } on SocketException catch (error) {
      _showConnectionError(error);
    } on TimeoutException catch (error) {
      _showConnectionError(error);
    } on HttpException catch (error) {
      _showConnectionError(error);
    } on FormatException catch (error) {
      _showConnectionError(error);
    } on XmlException catch (error) {
      _showConnectionError(error);
    } on PlatformException catch (error) {
      _showConnectionError(error);
    } catch (error) {
      debugPrint('ONVIF connection failed: ${error.runtimeType}');
      _showConnectionError(error);
    }
  }

  void _showSearchError() {
    if (!mounted) return;
    setState(() {
      _error = widget.english
          ? 'Could not search this network. Check local-network permission, or enter the stream URL manually.'
          : 'No se pudo buscar en esta red. Revisa el permiso de red local o escribe la URL del stream manualmente.';
      _searching = false;
    });
  }

  void _showConnectionError([Object? error]) {
    if (!mounted) return;
    setState(() {
      final reason = switch (error) {
        SocketException() => widget.english
            ? 'The phone could not reach the camera on the local network.'
            : 'El teléfono no pudo alcanzar la cámara en la red local.',
        TimeoutException() => widget.english
            ? 'The camera did not answer in time.'
            : 'La cámara no respondió a tiempo.',
        HttpException() => widget.english
            ? 'The camera rejected the ONVIF request. Check the camera username and password.'
            : 'La cámara rechazó la solicitud ONVIF. Verifica el usuario y la contraseña de la cámara.',
        FormatException() || XmlException() => widget.english
            ? 'The camera did not return an ONVIF video profile or a usable RTSP address.'
            : 'La cámara no devolvió un perfil de video ONVIF o una dirección RTSP utilizable.',
        _ => widget.english
            ? 'The camera could not complete ONVIF setup.'
            : 'No se pudo completar la conexión ONVIF con la cámara.',
      };
      final nextStep = widget.english
          ? ' Confirm ONVIF is enabled in the camera settings. If it still fails, enter the RTSP stream URL manually.'
          : ' Confirma que ONVIF esté habilitado en los ajustes de la cámara. Si sigue fallando, escribe manualmente la URL del stream RTSP.';
      _error = '$reason$nextStep';
      _searching = false;
    });
  }

  Future<void> _enterRtspUrl() async {
    await _showManualRtspDialog();
  }

  Future<void> _tryStream2Fallback() async {
    final camera = _failedCamera;
    if (camera == null) return;
    await _showManualRtspDialog(
      initialUri: buildStream2FallbackUri(camera),
    );
  }

  Future<void> _showManualRtspDialog({Uri? initialUri}) async {
    final camera = _failedCamera;
    if (camera == null) return;
    final url = await showDialog<Uri>(
      context: context,
      builder: (context) => _ManualRtspDialog(
        camera: camera,
        english: widget.english,
        initialCredentials: _failedCredentials,
        initialUri: initialUri,
      ),
    );
    if (url == null || !mounted) return;
    Navigator.pop(context, url.toString());
  }

  @override
  Widget build(BuildContext context) {
    final english = widget.english;
    return AlertDialog(
      title: Text(english ? 'Cameras on this Wi-Fi' : 'Cámaras en este Wi-Fi'),
      content: SizedBox(
        width: 360,
        child: _searching
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(english
                      ? 'Searching for ONVIF devices…'
                      : 'Buscando dispositivos ONVIF…'),
                ],
              )
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _enterRtspUrl,
                        icon: const Icon(Icons.link),
                        label: Text(
                          english
                              ? 'Enter RTSP stream URL'
                              : 'Escribir URL del stream RTSP',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _tryStream2Fallback,
                        icon: const Icon(Icons.flash_on),
                        label: Text(
                          english
                              ? 'Try RTSP path /stream2'
                              : 'Probar ruta RTSP /stream2',
                        ),
                      ),
                    ],
                  )
                : _cameras.isEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Platform.isIOS
                                ? (english
                                    ? 'This iPhone build cannot discover ONVIF cameras automatically: Apple requires a separately approved multicast-network entitlement, which is not included. Make sure both devices use the same Wi-Fi, then return and enter the camera RTSP URL manually.'
                                    : 'Esta versión para iPhone no puede buscar cámaras ONVIF automáticamente: Apple exige una autorización especial para multicast que no está incluida. Conecta ambos dispositivos al mismo Wi-Fi, vuelve y escribe manualmente la URL RTSP de la cámara.')
                                : (english
                                    ? 'No ONVIF cameras found. Make sure the camera and phone are on the same Wi-Fi and that ONVIF is enabled. You can still enter the stream URL manually.'
                                    : 'No se encontraron cámaras ONVIF. Comprueba que la cámara y el teléfono estén en el mismo Wi-Fi y que ONVIF esté habilitado. También puedes escribir la URL manualmente.'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.link),
                            label: Text(
                              english
                                  ? 'Back to manual camera URL'
                                  : 'Volver a escribir la URL',
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        height: 240,
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final camera in _cameras)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.videocam),
                                title: Text(camera.name),
                                subtitle: Text(camera.address),
                                onTap: () => _connect(camera),
                              ),
                          ],
                        ),
                      ),
      ),
      actions: [
        if (!_searching)
          TextButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.refresh),
            label: Text(english ? 'Search again' : 'Buscar de nuevo'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(english ? 'Cancel' : 'Cancelar'),
        ),
      ],
    );
  }
}

class _ManualRtspDialog extends StatefulWidget {
  final OnvifCamera camera;
  final bool english;
  final (String, String)? initialCredentials;
  final Uri? initialUri;

  const _ManualRtspDialog({
    required this.camera,
    required this.english,
    required this.initialCredentials,
    required this.initialUri,
  });

  @override
  State<_ManualRtspDialog> createState() => _ManualRtspDialogState();
}

class _ManualRtspDialogState extends State<_ManualRtspDialog> {
  late final TextEditingController _controller = TextEditingController(
    text:
        widget.initialUri?.toString() ?? 'rtsp://${widget.camera.address}:554/',
  );
  late final TextEditingController _usernameController =
      TextEditingController(text: widget.initialCredentials?.$1 ?? '');
  late final TextEditingController _passwordController =
      TextEditingController(text: widget.initialCredentials?.$2 ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final english = widget.english;
    return AlertDialog(
      title: Text(english ? 'Enter RTSP address' : 'Escribe la dirección RTSP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            english
                ? 'Use the RTSP address provided by the camera or its app. The address must point to this camera (${widget.camera.address}).'
                : 'Usa la dirección RTSP indicada por la cámara o su aplicación. La dirección debe corresponder a esta cámara (${widget.camera.address}).',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: english ? 'RTSP stream URL' : 'URL del stream RTSP',
              hintText: 'rtsp://${widget.camera.address}:554/stream',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: english ? 'RTSP username' : 'Usuario RTSP',
            ),
          ),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: english ? 'RTSP password' : 'Contraseña RTSP',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(english ? 'Cancel' : 'Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final uri = Uri.tryParse(_controller.text.trim());
            if (uri == null ||
                uri.scheme.toLowerCase() != 'rtsp' ||
                uri.host != widget.camera.address ||
                uri.path.isEmpty ||
                uri.path == '/') {
              setState(() {
                _error = english
                    ? 'Enter a complete RTSP URL for this camera, including its stream path.'
                    : 'Escribe una URL RTSP completa de esta cámara, incluida la ruta del stream.';
              });
              return;
            }
            final username = _usernameController.text.trim();
            final password = _passwordController.text;
            final streamUri = uri.userInfo.isNotEmpty ||
                    (username.isEmpty && password.isEmpty)
                ? uri
                : uri.replace(userInfo: '$username:$password');
            Navigator.pop(context, streamUri);
          },
          child: Text(english ? 'Connect' : 'Conectar'),
        ),
      ],
    );
  }
}

class _OnvifCredentialsDialog extends StatefulWidget {
  final bool english;

  const _OnvifCredentialsDialog({required this.english});

  @override
  State<_OnvifCredentialsDialog> createState() =>
      _OnvifCredentialsDialogState();
}

class _OnvifCredentialsDialogState extends State<_OnvifCredentialsDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final english = widget.english;
    return AlertDialog(
      title: Text(english ? 'Camera credentials' : 'Credenciales de la cámara'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            english
                ? 'Credentials are used locally to request the video stream.'
                : 'Las credenciales se usan localmente para solicitar el stream de video.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            autofocus: true,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: english ? 'Username' : 'Usuario',
            ),
          ),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: english ? 'Password' : 'Contraseña',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(english ? 'Cancel' : 'Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              (
                _usernameController.text.trim(),
                _passwordController.text,
              ),
            );
          },
          child: Text(english ? 'Connect' : 'Conectar'),
        ),
      ],
    );
  }
}
