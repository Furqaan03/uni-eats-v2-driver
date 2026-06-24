import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/driver_provider.dart';
import '../../services/firestore_order_service.dart';

class NewOrderScreen extends StatefulWidget {
  /// True when the card sits at the very bottom of the screen (no active delivery bar below it).
  /// Controls whether SafeArea adds bottom inset for the home indicator.
  final bool atBottom;
  const NewOrderScreen({super.key, this.atBottom = true});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerCtrl;
  static const _totalSeconds = 30;
  bool _isCritical = false;

  @override
  void initState() {
    super.initState();
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalSeconds),
    )
      ..addListener(() {
        final remaining = (1 - _timerCtrl.value) * _totalSeconds;
        final critical = remaining <= 10;
        if (critical != _isCritical) {
          setState(() => _isCritical = critical);
        }
        if (_timerCtrl.isCompleted) {
          context.read<DriverProvider>().rejectOrder();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    super.dispose();
  }

  Future<void> _showDeclineReasonDialog(BuildContext context, DriverProvider driver) async {
    _timerCtrl.stop();
    final reasons = [
      'Too far away',
      'Heavy traffic',
      'Vehicle issue',
      'Restaurant closed',
      'Personal emergency',
      'Other',
    ];
    String? selected;
    final otherCtrl = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: const Text(
            'Why are you declining?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
              fontSize: 16,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...reasons.map(
                  (r) => InkWell(
                    onTap: () => setS(() => selected = r),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected == r ? AppColors.yellow : AppColors.darkBorder,
                                width: selected == r ? 6 : 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            r,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected == r ? FontWeight.w700 : FontWeight.w500,
                              color: selected == r ? AppColors.darkText : AppColors.darkSubText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (selected == 'Other')
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: otherCtrl,
                      autofocus: true,
                      style: const TextStyle(color: AppColors.darkText, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Describe the reason...',
                        hintStyle: const TextStyle(color: AppColors.darkSubText, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.darkCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.darkBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.darkBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.yellow),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      maxLines: 2,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel', style: TextStyle(color: AppColors.darkSubText)),
            ),
            TextButton(
              onPressed: selected == null
                  ? null
                  : () {
                      final finalReason = selected == 'Other'
                          ? (otherCtrl.text.trim().isNotEmpty ? otherCtrl.text.trim() : 'Other')
                          : selected!;
                      Navigator.pop(ctx, finalReason);
                    },
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('Submit & Decline', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (reason != null) {
      driver.declineWithReason(reason);
    } else {
      _timerCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.read<DriverProvider>();
    final accent = _isCritical ? AppColors.red : AppColors.yellow;

    // This screen is only ever shown while driver.hasIncomingOrder is true,
    // which is only ever set alongside a real Firestore order or a mock
    // template — so incomingRestaurant should never actually be null here.
    // If it somehow is (an inconsistent-state bug elsewhere), don't fabricate
    // a fake "Campus Kitchen, QAR 5" order for the driver to act on — bail
    // out instead.
    if (driver.incomingRestaurant == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (driver.hasIncomingOrder) driver.rejectOrder();
      });
      return const SizedBox.shrink();
    }

    final restaurant = driver.incomingRestaurant!;
    final stall = driver.incomingStall ?? 'Counter';
    final dropoff = driver.incomingDropoff ?? 'Campus';
    final payout = driver.incomingPayout ?? kDriverPayoutPerDelivery;
    final distKm = driver.incomingDistKm ?? 1.5;
    final etaMin = driver.incomingEtaMin ?? 15;
    final itemCount = driver.incomingItemCount ?? 1;
    final foodType = driver.incomingFoodType ?? '🍽 Food';
    final etaRestaurant = (etaMin * 0.4).ceil();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: widget.atBottom,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header row: title + compact timer
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _isCritical ? '⚠️ Hurry Up!' : '🛵 New Order',
                            key: ValueKey(_isCritical),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$restaurant  •  $itemCount items  •  $foodType',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFCCCCCC)),
                        ),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _timerCtrl,
                    builder: (_, __) {
                      final remaining = ((1 - _timerCtrl.value) * _totalSeconds).ceil();
                      return _CompactCountdown(
                        progress: 1 - _timerCtrl.value,
                        remaining: remaining,
                        isCritical: _isCritical,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Route card
              _RouteCard(
                restaurant: restaurant,
                stall: stall,
                dropoff: dropoff,
                etaRestaurantMin: etaRestaurant,
                etaTotalMin: etaMin,
              ),
              const SizedBox(height: 12),

              // Meta chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MetaChip(
                    icon: Icons.attach_money,
                    label: 'QAR ${payout.toStringAsFixed(2)}',
                    accent: AppColors.green,
                  ),
                  _MetaChip(icon: Icons.route, label: '${distKm.toStringAsFixed(1)} km'),
                  _MetaChip(icon: Icons.access_time, label: '~$etaMin min'),
                  _MetaChip(
                    icon: Icons.shopping_bag_outlined,
                    label: '$itemCount item${itemCount == 1 ? '' : 's'}',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showDeclineReasonDialog(context, driver),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: const Text(
                          'Decline',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFCCCCCC),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        _timerCtrl.stop();
                        driver.acceptOrder();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isCritical
                                ? [const Color(0xFFFF6B6B), AppColors.red]
                                : [AppColors.orangeLight, AppColors.orangeDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Accept Order',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactCountdown extends StatelessWidget {
  final double progress;
  final int remaining;
  final bool isCritical;
  const _CompactCountdown({
    required this.progress,
    required this.remaining,
    required this.isCritical,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(progress: progress, isCritical: isCritical),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$remaining',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkText,
                ),
              ),
              Text('sec', style: TextStyle(fontSize: 8, color: AppColors.darkSubText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isCritical;
  _RingPainter({required this.progress, required this.isCritical});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.darkBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * (1 - progress),
      false,
      Paint()
        ..color = isCritical ? AppColors.red : AppColors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.isCritical != isCritical;
}

class _RouteCard extends StatelessWidget {
  final String restaurant;
  final String stall;
  final String dropoff;
  final int etaRestaurantMin;
  final int etaTotalMin;
  const _RouteCard({
    required this.restaurant,
    required this.stall,
    required this.dropoff,
    required this.etaRestaurantMin,
    required this.etaTotalMin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          _RouteRow(
            dot: AppColors.yellow,
            label: 'PICKUP',
            place: '$restaurant • $stall',
            sub: '~${etaRestaurantMin} min',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 2, bottom: 2),
            child: Column(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(width: 2, height: 5, color: AppColors.darkBorder),
                  ),
                ),
              ),
            ),
          ),
          _RouteRow(
            dot: AppColors.green,
            label: 'DROPOFF',
            place: dropoff,
            sub: '~$etaTotalMin min',
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final Color dot;
  final String label;
  final String place;
  final String sub;
  const _RouteRow({
    required this.dot,
    required this.label,
    required this.place,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFBBBBBB),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                place,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
        Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFFCCCCCC))),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;
  const _MetaChip({required this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent ?? AppColors.darkSubText),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent ?? AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }
}
