import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/realtime/realtime_service.dart';
import 'core/storage/local_store.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/native_appearance.dart';
import 'features/app/app_controller.dart';
import 'features/calendar/local_reminder_service.dart';
import 'features/home/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never leave Flutter's diagnostic baseline/bounds overlays active in the
  // app preview. Assign outside assert so this is reliable in every build.
  debugPaintBaselinesEnabled = false;
  debugPaintSizeEnabled = false;
  debugPaintPointersEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugRepaintRainbowEnabled = false;
  WidgetsBinding.instance.addPersistentFrameCallback((_) {
    debugPaintBaselinesEnabled = false;
    debugPaintSizeEnabled = false;
    debugPaintPointersEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugRepaintRainbowEnabled = false;
  });
  final local = await LocalStore.open();
  // Resolve the saved appearance before the first Flutter frame. Otherwise
  // MaterialApp briefly builds in light mode and then switches after restore().
  final initialDarkMode = await local.readJson('appearance:dark_mode') == true;
  await NativeAppearance.setDarkMode(initialDarkMode);
  try {
    await LocalReminderService.instance.initialize();
  } catch (_) {
    // Notification support is optional on development and unsupported devices.
  }
  final controller = AppController(
    api: ApiClient(),
    local: local,
    realtime: RealtimeService(),
  );
  controller.darkModeEnabled = initialDarkMode;
  runApp(
    ChangeNotifierProvider.value(
      value: controller,
      child: const ALaStudieApp(),
    ),
  );
  unawaited(controller.restore());
}

class ALaStudieApp extends StatelessWidget {
  const ALaStudieApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'aLaStudie',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    darkTheme: buildAppTheme(brightness: Brightness.dark),
    themeMode: context.watch<AppController>().darkModeEnabled
        ? ThemeMode.dark
        : ThemeMode.light,
    home: const AppRoot(),
  );
}
