import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_edit_actions/macos_edit_actions.dart';

/// A window with two text fields for checking the plugin against the real engine.
/// Every change of a field is written to a file in the app's temporary directory, so a
/// script can read what the field really holds. If `fix.txt` there says `off` at start,
/// the plugin is switched off first, to show the problem for comparison.
void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: ExamplePage());
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String _status = '…';

  File _file(String name) => File('${Directory.systemTemp.path}/$name');

  @override
  void initState() {
    super.initState();
    _first.addListener(() => _write('field1.txt', _first));
    _second.addListener(() => _write('field2.txt', _second));
    _start();
  }

  void _write(String name, TextEditingController controller) {
    final value = controller.value;
    _file(name).writeAsStringSync(
      jsonEncode({
        'text': value.text,
        'base': value.selection.baseOffset,
        'extent': value.selection.extentOffset,
      }),
    );
  }

  Future<void> _start() async {
    final switchFile = _file('fix.txt');
    const actions = MacosEditActions();
    if (switchFile.existsSync() && switchFile.readAsStringSync().trim() == 'off') {
      await actions.setEnabled(false);
    }
    final status = await actions.status();
    _file('status.json').writeAsStringSync(jsonEncode(status));
    if (mounted) setState(() => _status = jsonEncode(status));
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('macos_edit_actions example'),
          const SizedBox(height: 16),
          TextField(
            controller: _first,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'First field'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _second,
            decoration: const InputDecoration(labelText: 'Second field'),
          ),
          const SizedBox(height: 16),
          Text(_status, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
}
