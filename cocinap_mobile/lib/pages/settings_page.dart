import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/standalone_provider.dart';
import '../providers/tour_controller.dart';
import '../services/settings_service.dart';
import '../services/background_service.dart';
import '../services/remote_camera_server.dart';
import '../services/remote_cloud_service.dart';
import '../services/remote_cloud_host_service.dart';
import '../content/content.dart';
import '../widgets/camera_url_dialog.dart';
import '../widgets/remote_desktop_dialog.dart';
import '../widgets/remote_cloud_pairing_dialog.dart';
import 'help_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _remoteHostEnabled = false;
  bool _remoteHostLoading = false;
  String _remoteHostApiKey = '';
  bool _cloudHostEnabled = false;
  bool _cloudHostLoading = false;
  String? _cloudHostError;
  RemoteCloudCredentials? _cloudCredentials;

  @override
  void initState() {
    super.initState();
    _loadStandalone();
  }

  Future<void> _loadStandalone() async {
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    standalone.setDurationMinutes(await settings.getStandaloneDuration());
    standalone
        .setNoPersonAlertSeconds(await settings.getStandaloneNoPersonSeconds());
    standalone.setDangerMinutes(await settings.getStandaloneDangerMinutes());
    standalone.setConfidence(await settings.getStandaloneConfidence());

    final src = await settings.getStandaloneSource();
    standalone.setCameraUrl(await settings.getStandaloneCameraUrl());
    standalone.setDesktopConnection(
      serverUrl: await settings.getServerUrl() ?? '',
      apiKey: await settings.getApiKey(),
    );
    standalone.setCameraSource(switch (src) {
      'ip' => StandaloneCameraSource.ipCamera,
      'remote' => StandaloneCameraSource.remoteDesktop,
      'cloud' => StandaloneCameraSource.remoteCloud,
      _ => StandaloneCameraSource.phone,
    });

    standalone.setAlertIntervals(await settings.getAlertIntervals());
    standalone
        .setIntervalAlertsEnabled(await settings.getIntervalAlertsEnabled());
    final repeat = await settings.getAlertRepeatMode();
    standalone.setRepeatMode(repeat == 'oncePerInterval'
        ? AlertRepeatMode.oncePerInterval
        : AlertRepeatMode.repeatLast);

    if (Platform.isWindows) {
      var enabled = await settings.getDesktopRemoteHostEnabled();
      var cloudEnabled = await settings.getRemoteCloudHostEnabled();
      var apiKey = '';
      final cloudCredentials = await settings.getRemoteCloudCredentials();
      if (enabled || cloudEnabled) {
        apiKey = await settings.getDesktopHostApiKey();
        try {
          await RemoteCameraServer.instance.start(
            apiKey: apiKey,
            getFrame: () => standalone.latestCameraJpeg,
            getFrameTime: () => standalone.latestCameraFrameAt,
          );
        } catch (error) {
          debugPrint('Could not restore remote camera host: $error');
          await settings.setDesktopRemoteHostEnabled(false);
          enabled = false;
          apiKey = '';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocal.language == 'en'
                      ? 'Remote access could not start: $error'
                      : 'No se pudo iniciar el acceso remoto: $error',
                ),
              ),
            );
          }
        }
      }
      if (cloudEnabled && cloudCredentials != null) {
        try {
          await RemoteCloudHostService.instance.start(
            credentials: cloudCredentials,
            provider: standalone,
            localApiKey: apiKey,
          );
        } catch (error) {
          debugPrint('Could not restore remote cloud host: $error');
          if (mounted) {
            setState(() {
              _cloudHostError = AppLocal.language == 'en'
                  ? 'Cloud publishing could not start: $error'
                  : 'No se pudo iniciar la transmisión en la nube: $error';
            });
          }
        }
      } else if (cloudEnabled) {
        cloudEnabled = false;
        await settings.setRemoteCloudHostEnabled(false);
      }
      if (mounted) {
        setState(() {
          _remoteHostEnabled = enabled;
          _remoteHostApiKey = apiKey;
          _cloudHostEnabled = cloudEnabled;
          _cloudCredentials = cloudCredentials;
        });
      }
    }
  }

  Future<void> _setRemoteHostEnabled(bool enabled) async {
    final settings = context.read<SettingsService>();
    final standalone = context.read<StandaloneProvider>();
    setState(() => _remoteHostLoading = true);
    try {
      if (enabled) {
        final apiKey = await settings.getDesktopHostApiKey();
        await RemoteCameraServer.instance.start(
          apiKey: apiKey,
          getFrame: () => standalone.latestCameraJpeg,
          getFrameTime: () => standalone.latestCameraFrameAt,
        );
        await settings.setDesktopRemoteHostEnabled(true);
        if (mounted) {
          setState(() {
            _remoteHostEnabled = true;
            _remoteHostApiKey = apiKey;
          });
        }
      } else {
        await RemoteCameraServer.instance.stop();
        await settings.setDesktopRemoteHostEnabled(false);
        if (mounted) {
          setState(() {
            _remoteHostEnabled = false;
            _remoteHostApiKey = '';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocal.language == 'en'
                  ? 'Could not change remote access: $error'
                  : 'No se pudo cambiar el acceso remoto: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _remoteHostLoading = false);
    }
  }

  Future<void> _copyRemoteHostApiKey() async {
    await Clipboard.setData(ClipboardData(text: _remoteHostApiKey));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocal.language == 'en' ? 'API key copied' : 'Clave API copiada',
        ),
      ),
    );
  }

  Future<void> _setCloudHostEnabled(bool enabled) async {
    final settings = context.read<SettingsService>();
    final standalone = context.read<StandaloneProvider>();
    setState(() {
      _cloudHostLoading = true;
      _cloudHostError = null;
    });
    try {
      if (enabled) {
        var credentials = _cloudCredentials;
        if (credentials == null || credentials.ownerKey.isEmpty) {
          credentials = RemoteCloudCredentials.create(
            gatewayUrl: RemoteCloudCredentials.defaultGatewayUrl,
          );
          await RemoteCloudService().registerDevice(credentials);
          await settings.setRemoteCloudCredentials(credentials);
          if (mounted) setState(() => _cloudCredentials = credentials);
        }

        final apiKey = await settings.getDesktopHostApiKey();
        await RemoteCloudHostService.instance.start(
          credentials: credentials,
          provider: standalone,
          localApiKey: apiKey,
        );
        await settings.setRemoteCloudHostEnabled(true);
        if (!mounted) return;
        setState(() {
          _cloudHostEnabled = true;
          _cloudCredentials = credentials;
        });
        await _showCloudPairingQr(context, credentials);
      } else {
        await RemoteCloudHostService.instance.stop();
        await settings.setRemoteCloudHostEnabled(false);
        if (!_remoteHostEnabled) {
          await RemoteCameraServer.instance.stop();
        }
        if (mounted) {
          setState(() {
            _cloudHostEnabled = false;
            _cloudHostError = null;
          });
        }
      }
    } on FormatException catch (error) {
      _showCloudHostError(error.message.toString());
    } on HttpException catch (error) {
      _showCloudHostError(error.message);
    } on SocketException {
      _showCloudHostError(
        AppLocal.language == 'en'
            ? 'Could not reach the CocinaP cloud gateway.'
            : 'No se pudo conectar con el gateway de CocinaP Cloud.',
      );
    } catch (error) {
      _showCloudHostError(error.toString());
    } finally {
      if (mounted) setState(() => _cloudHostLoading = false);
    }
  }

  Future<void> _showCloudPairingQr(
    BuildContext context,
    RemoteCloudCredentials credentials,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppLocal.language == 'en' ? 'Pair your phone' : 'Vincula tu teléfono',
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocal.language == 'en'
                    ? 'Scan this QR from the phone. Keep it private: it grants access to the camera video.'
                    : 'Escanea este QR desde el teléfono. No lo compartas: permite ver el video de la cámara.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: credentials.toInvite(),
                size: 240,
                backgroundColor: Colors.white,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocal.language == 'en' ? 'Close' : 'Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showCloudHostError(String error) {
    if (!mounted) return;
    setState(() => _cloudHostError = error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  /// Edita la lista de intervalos de alerta (minutos sin persona).
  Future<void> _editIntervals(BuildContext context) async {
    final lang = AppLocal.language;
    String l(String es, String en) => lang == "en" ? en : es;
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final intervals = standalone.sortedIntervals;
          return AlertDialog(
            title: Text(l("Intervalos de alerta", "Alert intervals")),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l("Avisa cuando la cocina lleva estos minutos sin persona. Ejemplo: 10, 15 y 20 min.",
                        "Alert when kitchen has been without person for these minutes. Example: 10, 15, 20 min."),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText:
                                l("Minutos (ej. 25)", "Minutes (e.g. 25)"),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final m = int.tryParse(controller.text);
                          if (m == null || m < 1 || m > 240) return;
                          final next = [...intervals, m];
                          standalone.setAlertIntervals(next);
                          controller.clear();
                          setLocal(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (intervals.isEmpty)
                    Text(l("Sin intervalos", "No intervals"),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: intervals
                          .map(
                            (m) => InputChip(
                              label: Text("$m min"),
                              onDeleted: () {
                                final next =
                                    intervals.where((x) => x != m).toList();
                                standalone.setAlertIntervals(next);
                                setLocal(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l("Cerrar", "Close")),
              ),
            ],
          );
        },
      ),
    );

    await settings.setAlertIntervals(standalone.alertIntervals);
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final current = AppLocal.language;
    final settings = context.read<SettingsService>();
    final sel = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Idioma / Language"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, "es"),
            child: const Text("Español"),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, "en"),
            child: const Text("English"),
          ),
        ],
      ),
    );
    if (sel != null && sel != current) {
      AppLocal.setLanguage(sel);
      await settings.setLanguage(sel);
      if (mounted) setState(() {});
    }
  }

  Future<void> _chooseCameraSource(BuildContext context) async {
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    final lang = AppLocal.language;
    final source = await showDialog<StandaloneCameraSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(lang == "en" ? "Camera source" : "Fuente de cámara"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, StandaloneCameraSource.phone),
            child: Text(
              defaultTargetPlatform == TargetPlatform.windows
                  ? (lang == "en" ? "Windows camera" : "Cámara de Windows")
                  : (lang == "en" ? "Phone camera" : "Cámara del móvil"),
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(ctx, StandaloneCameraSource.ipCamera),
            child: Text(lang == "en" ? "IP camera" : "Cámara IP"),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(ctx, StandaloneCameraSource.remoteDesktop),
            child: Text(
              lang == "en"
                  ? "Remote CocinaP Desktop"
                  : "CocinaP Escritorio remoto",
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(ctx, StandaloneCameraSource.remoteCloud),
            child: Text(
              lang == 'en'
                  ? 'Remote PC over CocinaP Cloud'
                  : 'PC remota por CocinaP Cloud',
            ),
          ),
        ],
      ),
    );
    if (source == null) return;
    if (!context.mounted) return;

    if (source == StandaloneCameraSource.ipCamera) {
      final url = await showCameraUrlDialog(
        context,
        currentUrl: standalone.cameraUrl,
        language: lang,
      );
      if (url == null) return;
      if (!context.mounted) return;
      standalone.setCameraSource(source);
      standalone.setCameraUrl(url);
      await settings.setStandaloneCameraUrl(url);
      await settings.setStandaloneSourceIndex(1);
    } else if (source == StandaloneCameraSource.remoteDesktop) {
      await _editRemoteDesktop(context);
      return;
    } else if (source == StandaloneCameraSource.remoteCloud) {
      await _pairRemoteCloud(context);
      return;
    } else {
      standalone.setCameraSource(source);
    }
    if (source == StandaloneCameraSource.phone) {
      await settings.setStandaloneSourceIndex(0);
    }
  }

  Future<void> _pairRemoteCloud(BuildContext context) async {
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    final credentials = await showRemoteCloudPairingDialog(
      context,
      language: AppLocal.language,
    );
    if (credentials == null || !context.mounted) return;
    try {
      await RemoteCloudService().requestViewerToken(credentials);
      await settings.setRemoteCloudCredentials(credentials);
      standalone.setCameraSource(StandaloneCameraSource.remoteCloud);
      await settings.setStandaloneSourceIndex(3);
    } on HttpException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on SocketException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocal.language == 'en'
                ? 'Could not reach CocinaP Cloud.'
                : 'No se pudo conectar con CocinaP Cloud.',
          ),
        ),
      );
    }
  }

  Future<void> _editRemoteDesktop(
    BuildContext context, {
    bool selectSource = true,
  }) async {
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    final config = await showRemoteDesktopDialog(
      context,
      language: AppLocal.language,
      initialBaseUrl: standalone.desktopServerUrl,
      initialApiKey: standalone.desktopApiKey,
    );
    if (config == null || !context.mounted) return;

    standalone.setDesktopConnection(
      serverUrl: config.baseUrl,
      apiKey: config.apiKey,
    );
    if (selectSource) {
      standalone.setCameraSource(StandaloneCameraSource.remoteDesktop);
      await settings.setStandaloneSourceIndex(2);
    }
    await settings.setServerUrl(config.baseUrl);
    await settings.setApiKey(config.apiKey);
  }

  Future<void> _editCameraUrl(BuildContext context) async {
    final standalone = context.read<StandaloneProvider>();
    final settings = context.read<SettingsService>();
    final url = await showCameraUrlDialog(
      context,
      currentUrl: standalone.cameraUrl,
      language: AppLocal.language,
    );
    if (url == null || !context.mounted) return;
    standalone.setCameraSource(StandaloneCameraSource.ipCamera);
    standalone.setCameraUrl(url);
    await settings.setStandaloneCameraUrl(url);
    await settings.setStandaloneSourceIndex(1);
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocal.language;
    final standalone = context.watch<StandaloneProvider>();
    final settings = context.read<SettingsService>();

    String l(String es, String en) => lang == "en" ? en : es;

    return Scaffold(
      appBar: AppBar(title: Text(l("Ajustes", "Settings"))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              l("Monitoreo", "Monitoring"),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          // Fuente de cámara
          ListTile(
            leading: const Icon(Icons.videocam),
            title: Text(l("Fuente de cámara", "Camera source")),
            subtitle: Text(standalone.cameraSourceLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _chooseCameraSource(context),
          ),
          if (standalone.cameraSource == StandaloneCameraSource.ipCamera)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l("URL de cámara IP", "IP camera URL")),
              subtitle: Text(cameraUrlDisplayLabel(standalone.cameraUrl)),
              trailing: const Icon(Icons.edit),
              onTap: () => _editCameraUrl(context),
            ),
          if (standalone.cameraSource == StandaloneCameraSource.remoteDesktop)
            ListTile(
              leading: const Icon(Icons.cloud_sync),
              title: Text(l("PC remota", "Remote PC")),
              subtitle: Text(standalone.desktopServerUrl),
              trailing: const Icon(Icons.edit),
              onTap: () => _editRemoteDesktop(context, selectSource: false),
            ),
          if (standalone.cameraSource == StandaloneCameraSource.remoteCloud)
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(l('PC remota por la nube', 'Remote PC over cloud')),
              subtitle: Text(
                l(
                  'Las credenciales de video están vinculadas de forma segura.',
                  'Video access is securely paired.',
                ),
              ),
              trailing: const Icon(Icons.qr_code_scanner),
              onTap: () => _pairRemoteCloud(context),
            ),
          if (Platform.isWindows) ...[
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.vpn_lock),
              title: Text(l('Permitir acceso remoto', 'Allow remote access')),
              subtitle: Text(
                l(
                  'Sirve la cámara de este PC al móvil por Tailscale.',
                  'Serves this PC camera to your phone through Tailscale.',
                ),
              ),
              value: _remoteHostEnabled,
              onChanged: _remoteHostLoading ? null : _setRemoteHostEnabled,
            ),
            if (_remoteHostEnabled) ...[
              ListTile(
                leading: const Icon(Icons.key),
                title: Text(l('Clave API', 'API key')),
                subtitle: SelectableText(_remoteHostApiKey),
                trailing: IconButton(
                  tooltip: l('Copiar clave', 'Copy key'),
                  icon: const Icon(Icons.copy),
                  onPressed: _copyRemoteHostApiKey,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l(
                    'En PowerShell ejecuta `tailscale serve --bg 8080`; luego agrega en el móvil la dirección HTTPS .ts.net y esta clave. Mantén CocinaP abierto.',
                    'Run `tailscale serve --bg 8080` in PowerShell, then add the HTTPS .ts.net address and this key on your phone. Keep CocinaP open.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            SwitchListTile(
              secondary: const Icon(Icons.cloud_outlined),
              title: Text(
                l(
                  'Acceso remoto por nube (prueba)',
                  'Cloud remote access (test)',
                ),
              ),
              subtitle: Text(
                l(
                  'Prueba técnica sin cobro ni suscripción. Requiere internet, PC encendida y ffmpeg.exe junto a CocinaP.',
                  'Technical test with no billing or subscription. Requires internet, the PC to stay on, and ffmpeg.exe beside CocinaP.',
                ),
              ),
              value: _cloudHostEnabled,
              onChanged: _cloudHostLoading ? null : _setCloudHostEnabled,
            ),
            if (_cloudHostError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _cloudHostError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_cloudHostEnabled && _cloudCredentials != null)
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: Text(
                  l('Vincular teléfono', 'Pair phone'),
                ),
                subtitle: Text(
                  l(
                    'Escanea el código para abrir el video remoto.',
                    'Scan the code to open the remote video.',
                  ),
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _showCloudPairingQr(
                  context,
                  _cloudCredentials!,
                ),
              ),
          ],
          const Divider(),

          // Duración del temporizador
          ListTile(
            title: Text(
                l("Duración del monitoreo (min)", "Monitoring duration (min)")),
            trailing: SizedBox(
              width: 90,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (v) {
                  final min = (int.tryParse(v) ?? 30).clamp(1, 240).toInt();
                  standalone.setDurationMinutes(min);
                  settings.setStandaloneDuration(min);
                },
              ),
            ),
          ),

          // Tiempo sin persona antes de alertar
          ListTile(
            title: Text(
                l("Alertar si sin persona (seg)", "Alert if no person (sec)")),
            subtitle: Text(l("Tiempo sin detectar persona para disparar alerta",
                "Time without detecting person to trigger alert")),
            trailing: SizedBox(
              width: 90,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (v) {
                  final s = (int.tryParse(v) ?? 30).clamp(10, 120).toInt();
                  standalone.setNoPersonAlertSeconds(s);
                  settings.setStandaloneNoPersonSeconds(s);
                },
              ),
            ),
          ),

          // Intervalos de alerta (cocina desatendida)
          SwitchListTile(
            title: Text(l("Alertas por intervalos", "Interval alerts")),
            subtitle: Text(l(
                "Avisa a los 10, 15, 20 min... sin persona en la cocina",
                "Alert at 10, 15, 20 min... without person in kitchen")),
            value: standalone.intervalAlertsEnabled,
            onChanged: (v) {
              standalone.setIntervalAlertsEnabled(v);
              settings.setIntervalAlertsEnabled(v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l("Intervalos configurados", "Configured intervals")),
            subtitle: Text(standalone.sortedIntervals.isEmpty
                ? l("Sin intervalos", "No intervals")
                : standalone.sortedIntervals.map((m) => "$m min").join(", ")),
            trailing: const Icon(Icons.edit),
            onTap: () => _editIntervals(context),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title:
                Text(l("Repetición de la última alerta", "Repeat last alert")),
            subtitle: Text(standalone.repeatMode == AlertRepeatMode.repeatLast
                ? l("Repetir el último intervalo", "Repeat last interval")
                : l("Una sola vez por intervalo", "Once per interval")),
            trailing: Switch(
              value: standalone.repeatMode == AlertRepeatMode.repeatLast,
              onChanged: (v) {
                final mode = v
                    ? AlertRepeatMode.repeatLast
                    : AlertRepeatMode.oncePerInterval;
                standalone.setRepeatMode(mode);
                settings
                    .setAlertRepeatMode(v ? 'repeatLast' : 'oncePerInterval');
              },
            ),
          ),

          // Tiempo peligroso estimado
          ListTile(
            title: Text(l("Tiempo peligroso sin atender (min)",
                "Danger time unattended (min)")),
            subtitle: Text(l("Se considera riesgo alto después de este tiempo",
                "High risk after this time")),
            trailing: SizedBox(
              width: 90,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (v) {
                  final m = (int.tryParse(v) ?? 5).clamp(1, 60).toInt();
                  standalone.setDangerMinutes(m);
                  settings.setStandaloneDangerMinutes(m);
                },
              ),
            ),
          ),

          // Confianza de detección
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l("Confianza detección persona: ",
                          "Person detection confidence: ") +
                      standalone.confidence.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 14),
                ),
                Slider(
                  value: standalone.confidence,
                  min: 0.2,
                  max: 0.9,
                  divisions: 7,
                  label: standalone.confidence.toStringAsFixed(2),
                  onChanged: (v) {
                    standalone.setConfidence(v);
                    settings.setStandaloneConfidence(v);
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: Text(l("Notificaciones", "Notifications")),
            subtitle: Text(l("Avisos locales con sonido y vibración",
                "Local alerts with sound and vibration")),
            trailing: FilledButton.tonalIcon(
              onPressed: BackgroundServiceManager.sendTestAlarm,
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: Text(l("Probar", "Test")),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              l("Detección", "Detection"),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.smartphone),
            title: Text(l("En el móvil (ML Kit)", "On-device (ML Kit)")),
            subtitle: Text(l(
                "El modelo se ejecuta en el dispositivo, sin enviar imágenes",
                "Runs on device, no images sent")),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text("Idioma / Language"),
            subtitle: Text(AppLocal.language == "en" ? "English" : "Español"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(l("Tour de la interfaz", "Interface tour")),
            subtitle: Text(l("Repasa las pestañas y opciones principales",
                "Review tabs and main options")),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.read<TourController>().start(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(
                l("Manual de uso, guía y términos", "Manual, guide & terms")),
            subtitle: Text(l("Manual, guía de cámaras y términos",
                "Manual, camera guide & terms")),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpPage()),
            ),
          ),
        ],
      ),
    );
  }
}
