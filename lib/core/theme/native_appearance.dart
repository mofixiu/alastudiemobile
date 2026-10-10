import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the native launch screen in sync with the app's saved appearance.
abstract final class NativeAppearance {
  static const _channel = MethodChannel('com.alastudie/appearance');

  static Future<void> setDarkMode(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>('setDarkMode', enabled);
    } on MissingPluginException {
      // The Flutter UI still applies its own theme if a native host omits this.
    } on PlatformException {
      // Native launch appearance is an enhancement, not a startup dependency.
    }
  }
}
