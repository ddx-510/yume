import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app_services.dart';
import 'debug/debug_hooks.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/glass.dart';

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
    return MaterialApp(
      title: 'Yume',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      navigatorKey: DebugHooks.navigatorKey,
      builder: (context, child) => RepaintBoundary(
        key: DebugHooks.boundaryKey,
        child: GlassBackground(child: child!),
      ),
      home: const HomeScreen(),
    );
  }
}
