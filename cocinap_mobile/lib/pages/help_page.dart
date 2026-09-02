import 'package:flutter/material.dart';
import '../content/content.dart';

/// Contenido interno de la app: manual de uso, guía de cámaras y
/// términos y condiciones. Disponible en español e inglés.
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  int _section = 0; // 0=Manual, 1=Guía, 2=Términos
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ayuda e información"),
        actions: [
          IconButton(
            tooltip: "Idioma / Language",
            icon: const Icon(Icons.translate),
            onPressed: () => _promptLanguage(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text("Manual")),
                ButtonSegment(value: 1, label: Text("Guía de cámaras")),
                ButtonSegment(value: 2, label: Text("Términos")),
              ],
              selected: {_section},
              onSelectionChanged: (s) => setState(() => _section = s.first),
            ),
          ),
          Expanded(
            child: _section == 0
                ? _ManualView()
                : _section == 1
                    ? _CameraGuideView()
                    : _TermsView(
                        onAccept: () => setState(() => _accepted = true),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptLanguage(BuildContext context) async {
    final current = AppLocal.language;
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
    if (sel != null && mounted && sel != current) {
      AppLocal.setLanguage(sel);
      setState(() {});
    }
  }
}

class _ManualView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final texts = AppManual.texts(AppLocal.language);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocal.language == "en" ? "User manual" : "Manual de uso",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < texts.length; i += 2) ...[
            _TitleBlock(texts[i]),
            if (i + 1 < texts.length)
              _BodyBlock(texts[i + 1]),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CameraGuideView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = CameraGuide.texts(AppLocal.language);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocal.language == "en"
                ? "Camera connection guide"
                : "Guía para conectar cámaras",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i += 2) ...[
            _TitleBlock("${(i ~/ 2) + 1}. ${steps[i]}", color: Colors.green),
            if (i + 1 < steps.length)
              _BodyBlock(steps[i + 1]),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TermsView extends StatefulWidget {
  final VoidCallback onAccept;
  const _TermsView({required this.onAccept});

  @override
  State<_TermsView> createState() => _TermsViewState();
}

class _TermsViewState extends State<_TermsView> {
  bool _acceptedLocal = false;

  @override
  Widget build(BuildContext context) {
    final terms = AppTerms.texts(AppLocal.language);
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  AppLocal.language == "en"
                      ? "Terms & Conditions"
                      : "Términos y Condiciones",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < terms.length; i += 2) ...[
                  _TitleBlock(terms[i], color: Colors.grey),
                  if (i + 1 < terms.length)
                    _BodyBlock(terms[i + 1]),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _acceptedLocal
                    ? null
                    : () {
                        setState(() => _acceptedLocal = true);
                        widget.onAccept();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocal.language == "en"
                                  ? "Terms accepted"
                                  : "Términos aceptados",
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  AppLocal.language == "en"
                      ? "I accept the terms"
                      : "Aceptar los términos",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final String text;
  final Color? color;
  const _TitleBlock(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color ?? Colors.orange),
    );
  }
}

class _BodyBlock extends StatelessWidget {
  final String text;
  const _BodyBlock(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
    );
  }
}