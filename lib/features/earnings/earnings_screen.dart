import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/driver_provider.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Payout: QAR 142',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
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
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  labelColor: Colors.white,
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
                    trips: _todayTrips(),
                    isDark: isDark,
                    cardBg: cardBg,
                  ),
                  _EarningsTab(
                    heroValue: 'QAR 874.00',
                    heroSub: '47 trips this week',
                    barData: const [120, 98, 142, 100, 160, 130, 124],
                    trips: _weekTrips(),
                    isDark: isDark,
                    cardBg: cardBg,
                  ),
                  _EarningsTab(
                    heroValue: 'QAR 3,241.00',
                    heroSub: '182 trips this month',
                    barData: const [90, 110, 130, 80, 150, 120, 160],
                    trips: _weekTrips(),
                    isDark: isDark,
                    cardBg: cardBg,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_TripData> _todayTrips() => [
        _TripData(from: 'Campus Kitchen', to: 'Dorm Block C', amount: 18.50, time: '2:14 PM'),
        _TripData(from: 'Spice Garden', to: 'Library Plaza', amount: 14.00, time: '1:02 PM'),
        _TripData(from: 'Café Bliss', to: 'Engineering Block', amount: 22.00, time: '11:45 AM'),
      ];

  List<_TripData> _weekTrips() => [
        _TripData(from: 'Campus Kitchen', to: 'Dorm Block A', amount: 16.50, time: 'Mon'),
        _TripData(from: 'Noodle House', to: 'Admin Block', amount: 19.00, time: 'Tue'),
        _TripData(from: 'Burger Stop', to: 'Gym', amount: 21.00, time: 'Wed'),
      ];
}

class _TripData {
  final String from;
  final String to;
  final double amount;
  final String time;
  const _TripData({
    required this.from,
    required this.to,
    required this.amount,
    required this.time,
  });
}

class _EarningsTab extends StatelessWidget {
  final String heroValue;
  final String heroSub;
  final List<int> barData;
  final List<_TripData> trips;
  final bool isDark;
  final Color cardBg;

  const _EarningsTab({
    required this.heroValue,
    required this.heroSub,
    required this.barData,
    required this.trips,
    required this.isDark,
    required this.cardBg,
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
        Container(
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Bar chart
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
              CustomPaint(
                painter: _BarChartPainter(data: barData, isDark: isDark),
                child: const SizedBox(height: 100, width: double.infinity),
              ),
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
        ...trips.map((t) => _TripCard(trip: t, isDark: isDark, cardBg: cardBg)),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<int> data;
  final bool isDark;
  _BarChartPainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final max = data.reduce((a, b) => a > b ? a : b).toDouble();
    final barW = size.width / (data.length * 1.6);
    final gap = size.width / data.length;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < data.length; i++) {
      final h = (data[i] / max) * size.height;
      final x = i * gap + (gap - barW) / 2;
      final today = i == data.length - 2;

      paint.color = today ? AppColors.orange : AppColors.orange.withValues(alpha: 0.3);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barW, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.data != data;
}

class _TripCard extends StatelessWidget {
  final _TripData trip;
  final bool isDark;
  final Color cardBg;
  const _TripCard({required this.trip, required this.isDark, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.orange)),
              Container(width: 1, height: 18, color: AppColors.darkBorder),
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
                Text(trip.from,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    )),
                const SizedBox(height: 4),
                Text(trip.to,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                    )),
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
              Text(trip.time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.darkSubText,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
