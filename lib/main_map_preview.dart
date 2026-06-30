import 'package:flutter/material.dart';
import 'core/map/campus_map.dart';

/// Standalone preview entrypoint used ONLY to visually verify the dark-mode
/// campus map (building polygons) on a device without going through login.
/// Not shipped — run with: flutter run -t lib/main_map_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(child: CampusMap(isDark: true, followDriver: false)),
      ),
    ),
  );
}
