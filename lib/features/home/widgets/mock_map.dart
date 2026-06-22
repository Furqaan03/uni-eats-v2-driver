import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';

/// University of Doha for Science and Technology, Qatar — real-world anchor
/// point for the campus map. Building-level positions aren't geocoded yet,
/// so this just centers the live map on campus rather than plotting exact
/// per-building markers.
const _udstCampus = LatLng(25.3245, 51.4280);

/// Real OpenStreetMap-tiled map (no API key required) showing the driver's
/// approximate position, replacing the previous custom-painted fake map.
class MockMap extends StatelessWidget {
  final bool isDark;
  const MockMap({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      // Subtle dark-mode tint so the map matches the app's theme without
      // needing a separate dark tile provider.
      colorFilter: isDark
          ? const ColorFilter.matrix(<double>[
              0.6, 0, 0, 0, 20,
              0, 0.6, 0, 0, 20,
              0, 0, 0.6, 0, 20,
              0, 0, 0, 1, 0,
            ])
          : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: _udstCampus,
          initialZoom: 15.5,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.unieats.driver',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _udstCampus,
                width: 52,
                height: 52,
                child: const _PulseMarker(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseMarker extends StatefulWidget {
  const _PulseMarker();

  @override
  State<_PulseMarker> createState() => _PulseMarkerState();
}

class _PulseMarkerState extends State<_PulseMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 18.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.orange.withValues(alpha: 0.12),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.4),
              blurRadius: _pulse.value,
              spreadRadius: _pulse.value / 4,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.orangeLight, AppColors.orangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('🏍️', style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ),
    );
  }
}
