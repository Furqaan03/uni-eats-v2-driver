import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// A static custom-painted mock map so we don't need a Maps API key.
class MockMap extends StatelessWidget {
  final bool isDark;
  const MockMap({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapPainter(isDark: isDark),
      child: Stack(
        children: [
          // Driver marker
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseMarker(isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseMarker extends StatefulWidget {
  final bool isDark;
  const _PulseMarker({required this.isDark});

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

class _MapPainter extends CustomPainter {
  final bool isDark;
  _MapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = bg);

    // Grid lines
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Roads
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFCCCCCC);
    final roads = [
      Rect.fromLTWH(0, size.height * 0.28, size.width, 14),
      Rect.fromLTWH(0, size.height * 0.54, size.width, 14),
      Rect.fromLTWH(0, size.height * 0.74, size.width, 14),
      Rect.fromLTWH(size.width * 0.24, 0, 14, size.height),
      Rect.fromLTWH(size.width * 0.54, 0, 14, size.height),
      Rect.fromLTWH(size.width * 0.78, 0, 14, size.height),
    ];
    for (final r in roads) {
      canvas.drawRect(r, roadPaint);
    }

    // Blocks
    final blockPaint = Paint()
      ..color = isDark ? const Color(0xFF252525) : const Color(0xFFD8D8D8);
    final rrect = const Radius.circular(4);
    final blocks = [
      Rect.fromLTWH(size.width * .05, size.height * .08, size.width * .17, size.height * .17),
      Rect.fromLTWH(size.width * .29, size.height * .08, size.width * .22, size.height * .17),
      Rect.fromLTWH(size.width * .60, size.height * .08, size.width * .16, size.height * .14),
      Rect.fromLTWH(size.width * .05, size.height * .36, size.width * .16, size.height * .15),
      Rect.fromLTWH(size.width * .29, size.height * .36, size.width * .21, size.height * .13),
      Rect.fromLTWH(size.width * .60, size.height * .36, size.width * .16, size.height * .15),
      Rect.fromLTWH(size.width * .05, size.height * .60, size.width * .17, size.height * .11),
      Rect.fromLTWH(size.width * .29, size.height * .60, size.width * .21, size.height * .11),
      Rect.fromLTWH(size.width * .05, size.height * .79, size.width * .16, size.height * .15),
      Rect.fromLTWH(size.width * .29, size.height * .79, size.width * .22, size.height * .13),
      Rect.fromLTWH(size.width * .60, size.height * .79, size.width * .16, size.height * .13),
    ];
    for (final b in blocks) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, rrect), blockPaint);
    }

    // Park
    final parkPaint = Paint()
      ..color = isDark ? const Color(0xFF1A2A1A) : const Color(0xFFC8DCC8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .60, size.height * .60, size.width * .19, size.height * .11),
        const Radius.circular(6),
      ),
      parkPaint,
    );
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.isDark != isDark;
}
