import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/driver_provider.dart';
import '../../services/firestore_order_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<List<DeliveredTrip>> _todayTripsFuture;
  late Future<List<DeliveredTrip>> _weekTripsFuture;
  late Future<List<DeliveredTrip>> _monthTripsFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    _todayTripsFuture = FirestoreOrderService.instance.fetchTripHistory(kDriverId, startOfToday);
    _weekTripsFuture = FirestoreOrderService.instance
        .fetchTripHistory(kDriverId, startOfToday.subtract(const Duration(days: 7)));
    _monthTripsFuture = FirestoreOrderService.instance
        .fetchTripHistory(kDriverId, startOfToday.subtract(const Duration(days: 30)));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final driver = context.watch<DriverProvider>();
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    // AppColors.orange is a near-black brand color — reads fine as a dark
    // accent on light backgrounds, but is nearly invisible against dark
    // surfaces. Swap to a genuinely visible accent in dark mode only.
    final accent = isDark ? AppColors.yellow : AppColors.orange;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text(
                    'Earnings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showPayoutInfo(context, isDark),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Payout: QAR 142',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.info_outline_rounded, size: 13, color: accent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  // Dark mode's accent is bright yellow — dark text reads
                  // better on it than white does.
                  labelColor: isDark ? AppColors.darkBg : Colors.white,
                  unselectedLabelColor:
                      isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  tabs: const [
                    Tab(text: 'Today'),
                    Tab(text: 'Week'),
                    Tab(text: 'Month'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _EarningsTab(
                    heroValue: 'QAR ${driver.todayEarnings.toStringAsFixed(2)}',
                    heroSub: '${driver.todayTrips} trips today',
                    barData: const [40, 80, 60, 120, 90, 142, 0],
                    tripsFuture: _todayTripsFuture,
                    isDark: isDark,
                    cardBg: cardBg,
                    accent: accent,
                  ),
                  _EarningsTab(
                    heroValue: 'This Week',
                    heroSub: 'Last 7 days',
                    barData: const [120, 98, 142, 100, 160, 130, 124],
                    tripsFuture: _weekTripsFuture,
                    isDark: isDark,
                    cardBg: cardBg,
                    accent: accent,
                  ),
                  _EarningsTab(
                    heroValue: 'This Month',
                    heroSub: 'Last 30 days',
                    barData: const [90, 110, 130, 80, 150, 120, 160],
                    tripsFuture: _monthTripsFuture,
                    isDark: isDark,
                    cardBg: cardBg,
                    accent: accent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayoutInfo(BuildContext context, bool isDark) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'How Payouts Work',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        content: Text(
          'Your pending balance is transferred automatically to your registered '
          'bank account every Friday. No action needed on your end.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EarningsTab extends StatelessWidget {
  final String heroValue;
  final String heroSub;
  final List<int> barData;
  final Future<List<DeliveredTrip>> tripsFuture;
  final bool isDark;
  final Color cardBg;
  final Color accent;

  const _EarningsTab({
    required this.heroValue,
    required this.heroSub,
    required this.barData,
    required this.tripsFuture,
    required this.isDark,
    required this.cardBg,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // Hero gradient card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.orangeDark, Color(0xFFFF5500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Earnings',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                heroValue,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                heroSub,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Payout card
        GestureDetector(
          onTap: () => _showPayoutBreakdown(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                const Text('🏦', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Payout',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Friday, Jun 20',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Automatic',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: isDark ? AppColors.darkSubText : AppColors.lightSubText),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Bar chart — tap a bar to see that day's exact earnings
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Earnings Overview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 16),
              _InteractiveBarChart(data: barData, isDark: isDark, accent: accent),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map((d) => Text(
                          d,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.darkSubText
                                : AppColors.lightSubText,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Trip list
        Text(
          'Trip History',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<DeliveredTrip>>(
          future: tripsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Could not load trip history.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  ),
                ),
              );
            }
            final trips = snapshot.data ?? const [];
            if (trips.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No completed trips in this period yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  ),
                ),
              );
            }
            return Column(
              children: trips
                  .map((t) => _TripCard(trip: t, isDark: isDark, cardBg: cardBg, accent: accent))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showPayoutBreakdown(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Payout Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 16),
            _BreakdownRow(label: heroSub, value: heroValue, isDark: isDark),
            const Divider(height: 24),
            _BreakdownRow(label: 'Payout date', value: 'Friday, Jun 20', isDark: isDark),
            const SizedBox(height: 10),
            _BreakdownRow(label: 'Method', value: 'Automatic bank transfer', isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _BreakdownRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ],
    );
  }
}

class _InteractiveBarChart extends StatefulWidget {
  final List<int> data;
  final bool isDark;
  final Color accent;
  const _InteractiveBarChart({required this.data, required this.isDark, required this.accent});

  @override
  State<_InteractiveBarChart> createState() => _InteractiveBarChartState();
}

class _InteractiveBarChartState extends State<_InteractiveBarChart> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  int? _selected;

  void _selectFromDx(double dx, double width) {
    if (width <= 0) return;
    final gap = width / widget.data.length;
    final index = (dx / gap).floor().clamp(0, widget.data.length - 1);
    setState(() => _selected = _selected == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: _selected == null
              ? const SizedBox(height: 0, width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_days[_selected ?? 0]} · QAR ${widget.data[_selected ?? 0]}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: widget.accent,
                      ),
                    ),
                  ),
                ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _selectFromDx(d.localPosition.dx, constraints.maxWidth),
            child: CustomPaint(
              painter: _BarChartPainter(data: widget.data, accent: widget.accent),
              child: const SizedBox(height: 100, width: double.infinity),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<int> data;
  final Color accent;
  _BarChartPainter({required this.data, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final max = data.reduce((a, b) => a > b ? a : b).toDouble();
    final barW = size.width / (data.length * 1.6);
    final gap = size.width / data.length;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = accent;

    // Every bar gets the full accent color — the tapped bar's value already
    // surfaces in the label above, so the bars themselves don't need to dim
    // each other out.
    for (var i = 0; i < data.length; i++) {
      final h = (data[i] / max) * size.height;
      final x = i * gap + (gap - barW) / 2;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barW, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(rrect, fill);
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.data != data || old.accent != accent;
}

class _TripCard extends StatelessWidget {
  final DeliveredTrip trip;
  final bool isDark;
  final Color cardBg;
  final Color accent;
  const _TripCard({
    required this.trip,
    required this.isDark,
    required this.cardBg,
    required this.accent,
  });

  String get _timeLabel {
    final t = trip.deliveredAt;
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String get _dateLabel {
    final t = trip.deliveredAt;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}';
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trip.restaurant,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Delivered',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _BreakdownRow(label: 'Dropoff', value: trip.dropoff, isDark: isDark),
            const SizedBox(height: 10),
            _BreakdownRow(label: 'Delivered on', value: '$_dateLabel · $_timeLabel', isDark: isDark),
            const Divider(height: 24),
            _BreakdownRow(
              label: 'Trip earnings',
              value: 'QAR ${trip.amount.toStringAsFixed(2)}',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final subTextColor = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dividerColor),
        ),
        child: Row(
          children: [
            Column(
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
                Container(width: 1, height: 18, color: dividerColor),
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.green)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.restaurant,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      )),
                  const SizedBox(height: 4),
                  Text(trip.dropoff,
                      style: TextStyle(fontSize: 12, color: subTextColor)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'QAR ${trip.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 3),
                Text(_timeLabel, style: TextStyle(fontSize: 11, color: subTextColor)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: subTextColor),
          ],
        ),
      ),
    );
  }
}
