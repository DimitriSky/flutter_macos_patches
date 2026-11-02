import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_edit_actions/macos_edit_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('macos_edit_actions');
  const actions = MacosEditActions();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {'enabled': call.arguments?['enabled'] ?? true, 'handled': 3};
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('status and switch go to the native plugin on macOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(await actions.status(), {'enabled': true, 'handled': 3});
    expect((await actions.setEnabled(false))['enabled'], false);
    expect(calls.map((c) => c.method), ['status', 'setEnabled']);
    expect(calls.last.arguments, {'enabled': false});
  });

  test('other platforms never call the channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await actions.status(), {'supported': false});
    expect(await actions.setEnabled(true), {'supported': false});
    expect(calls, isEmpty);
  });
}
