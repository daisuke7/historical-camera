import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'strings.dart';
import 'ui/camera_screen.dart';

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
      home: const CameraScreen(),
    );
  }
}
