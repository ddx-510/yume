import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app_services.dart';
import 'debug/debug_hooks.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final services = await AppServices.create();
  DebugHooks.register(services);
  runApp(AppScope(services: services, child: const YumeApp()));
}

class YumeApp extends StatelessWidget {
  const YumeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFE85D8E);
    return MaterialApp(
      title: 'Yume',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      navigatorKey: DebugHooks.navigatorKey,
      builder: (context, child) =>
          RepaintBoundary(key: DebugHooks.boundaryKey, child: child),
      home: const HomeScreen(),
    );
  }
}
