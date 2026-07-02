import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'strings.dart';

void main() {
  runApp(const ProviderScope(child: HistoricalCameraApp()));
}

class HistoricalCameraApp extends StatelessWidget {
  const HistoricalCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.amber,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const _PlaceholderScreen(),
    );
  }
}

/// Boot-time placeholder; replaced by CameraScreen in task T4.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(Strings.appName, style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}
