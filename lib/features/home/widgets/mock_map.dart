import 'package:flutter/material.dart';
import '../../../core/map/campus_map.dart';

/// Home-screen campus map. Thin wrapper over [CampusMap] showing the full UDST
/// building set so the driver can browse drop points before/between orders.
class MockMap extends StatelessWidget {
  final bool isDark;
  const MockMap({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) => CampusMap(isDark: isDark);
}
