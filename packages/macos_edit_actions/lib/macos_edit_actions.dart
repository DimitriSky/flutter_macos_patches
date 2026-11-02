import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The fix is active as soon as the plugin is a dependency of a macOS app.
/// This class only exposes diagnostics and a switch for A/B checks.
class MacosEditActions {
  const MacosEditActions({
    this.channel = const MethodChannel('macos_edit_actions'),
  });

  final MethodChannel channel;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// `enabled`, `patched` and `skipped` commands (a command the engine already implements itself
  /// is skipped), `missing` engine class names and how many commands were `handled`.
  Future<Map<String, dynamic>> status() async {
    if (!supported) return {'supported': false};
    return Map<String, dynamic>.from(
      await channel.invokeMapMethod<String, dynamic>('status') ?? {},
    );
  }

  /// Turns the fix off and on at runtime, e.g. to show the problem for comparison.
  Future<Map<String, dynamic>> setEnabled(bool enabled) async {
    if (!supported) return {'supported': false};
    return Map<String, dynamic>.from(
      await channel.invokeMapMethod<String, dynamic>('setEnabled', {
            'enabled': enabled,
          }) ??
          {},
    );
  }
}
