import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/driver_provider.dart';
import '../../services/firestore_order_service.dart';
import 'widgets/date_range_sheet.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<List<DeliveredTrip>> _tripsFuture;

  // Custom date range state
  DateTimeRange? _customRange;
  Future<List<DeliveredTrip>>? _customTripsFuture;
  bool _customLoading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
    // One 30-day fetch backs Today/Week/Month — custom tab fetches on demand.
    _tripsFuture = FirestoreOrderService.instance
        .fetchTripHistory(kDriverId, DateTime.now().subtract(const Duration(days: 30)));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Real daily earnings, bucketed by weekday and summed across however many
  /// days back the chart looks — replaces the old hardcoded mock arrays.
  List<int> _bucketByWeekday(List<DeliveredTrip> trips, int daysBack) {
    final cutoff = DateTime.now().subtract(Duration(days: daysBack));
    final bucket = List<int>.filled(7, 0);
    for (final t in trips) {
      if (t.deliveredAt.isBefore(cutoff)) continue;
      bucket[t.deliveredAt.weekday - 1] += t.amount.round();
    }
    return bucket;
  }

  /// Buckets trips by calendar date for the custom range bar chart.
  /// Returns (amounts, labels) aligned to the days in the range.
  (List<int>, List<String>) _bucketByDate(
      List<DeliveredTrip> trips, DateTimeRange range) {
    final days = range.end.difference(range.start).inDays + 1;
    // Cap bars at 31 to keep the chart readable; group by week beyond that.
    final grouped = days <= 31;
    final bucketCount = grouped ? days : ((days / 7).ceil());
    final amounts = List<int>.filled(bucketCount, 0);
    final labels = List<String>.filled(bucketCount, '');

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    for (var i = 0; i < bucketCount; i++) {
      if (grouped) {
        final d = range.start.add(Duration(days: i));
        labels[i] = '${d.day}/${d.month}';
      } else {
        final d = range.start.add(Duration(days: i * 7));
        labels[i] = '${months[d.month - 1]} ${d.day}';
      }
    }

    for (final t in trips) {
      final offset = t.deliveredAt.difference(
        DateTime(range.start.year, range.start.month, range.start.day),
      ).inDays;
      if (offset < 0) continue;
      final bucketIdx = grouped ? offset : (offset ~/ 7);
      if (bucketIdx < bucketCount) {
        amounts[bucketIdx] += t.amount.round();
      }
    }

    return (amounts, labels);
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final picked = await showDateRangeSheet(
      context,
      initialRange: _customRange,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _customLoading = true;
      _customTripsFuture = FirestoreOrderService.instance
          .fetchTripHistoryForRange(
            kDriverId,
            DateTime(picked.start.year, picked.start.month, picked.start.day),
            DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
          )
          .then((t) {
        if (mounted) setState(() => _customLoading = false);
        return t;
      });
    });
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
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
        child: FutureBuilder<List<DeliveredTrip>>(
          future: _tripsFuture,
          builder: (context, snapshot) {
            final trips = snapshot.data ?? const [];
            final weekTrips = trips
                .where((t) =>
                    t.deliveredAt.isAfter(DateTime.now().subtract(const Duration(days: 7))))
                .toList();
            final weekTotal = weekTrips.fold<double>(0, (s, t) => s + t.amount);
            final monthTotal = trips.fold<double>(0, (s, t) => s + t.amount);

            return Column(
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
                        onTap: () => _showPayoutInfo(context, isDark, weekTotal),
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
                                // This week's earnings so far — the amount
                                // that will go out on the next automatic
                                // Friday payout. Used to be a hardcoded
                                // "QAR 142" regardless of actual earnings.
                                'Payout: QAR ${weekTotal.toStringAsFixed(0)}',
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
                  indicatorSize: TabBarIndicatorSize.tab,
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
                    Tab(text: 'By Date'),
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
                    barData: _bucketByWeekday(trips, 7),
                    isDark: isDark,
                    cardBg: cardBg,
                    accent: accent,
                  ),
                  _EarningsTab(
                    heroValue: 'QAR ${weekTotal.toStringAsFixed(2)}',
                    heroSub: '${weekTrips.length} trips · Last 7 days',
                    barData: _bucketByWeekday(trips, 7),
                    isDark: isDark,
                    cardBg: cardBg,
                    accent: accent,
                  ),
                  _EarningsTab(
                    heroValue: 'QAR ${monthTotal.toStringAsFixed(2)}',
                    heroSub: '${trips.length} trips · Last 30 days',
                    barData: _bucketByWeekday(trips, 30),
                    isDark: isDark,
                    cardBg: cardBg,
                    accent: accent,
                  ),
                  // Custom date range tab
                  _CustomDateTab(
                    customRange: _customRange,
                    customTripsFuture: _customTripsFuture,
                    customLoading: _customLoading,
                    isDark: isDark,
                    cardBg: cardBg,
                    accent: accent,
                    onPickRange: () => _pickCustomRange(context),
                    bucketByDate: _bucketByDate,
                    formatDate: _formatDate,
                  ),
                ],
              ),
            ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showPayoutInfo(BuildContext context, bool isDark, double weekTotal) {
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
          'Your pending balance of QAR ${weekTotal.toStringAsFixed(2)} is transferred '
          'automatically to your registered bank account every Friday. No action needed '
          'on your end.',
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
  final bool isDark;
  final Color cardBg;
  final Color accent;

  const _EarningsTab({
    required this.heroValue,
    required this.heroSub,
    required this.barData,
    required this.isDark,
    required this.cardBg,
    required this.accent,
  });

  /// The upcoming Friday — replaces a hardcoded "Friday, Jun 20" that never
  /// changed regardless of the actual date.
  String get _nextPayoutDateLabel {
    final now = DateTime.now();
    final daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
    final next = now.add(Duration(days: daysUntilFriday == 0 ? 7 : daysUntilFriday));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Friday, ${months[next.month - 1]} ${next.day}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // Hero card — dark surface, green accent mark, no gradient
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161616) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Green accent bar replaces gradient and signals "earnings active"
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Total Earnings',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                heroValue,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF0F0F0),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                heroSub,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                ),
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
                        _nextPayoutDateLabel,
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
            _BreakdownRow(label: 'Payout date', value: _nextPayoutDateLabel, isDark: isDark),
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
              painter: _BarChartPainter(
                data: widget.data,
                accent: widget.accent,
                selectedIndex: _selected,
              ),
              child: const SizedBox(height: 100, width: double.infinity),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Custom date range tab ────────────────────────────────────────────────────

class _CustomDateTab extends StatelessWidget {
  final DateTimeRange? customRange;
  final Future<List<DeliveredTrip>>? customTripsFuture;
  final bool customLoading;
  final bool isDark;
  final Color cardBg;
  final Color accent;
  final VoidCallback onPickRange;
  final (List<int>, List<String>) Function(List<DeliveredTrip>, DateTimeRange) bucketByDate;
  final String Function(DateTime) formatDate;

  const _CustomDateTab({
    required this.customRange,
    required this.customTripsFuture,
    required this.customLoading,
    required this.isDark,
    required this.cardBg,
    required this.accent,
    required this.onPickRange,
    required this.bucketByDate,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    // Picker button — always shown at the top
    Widget pickerButton = GestureDetector(
      onTap: onPickRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                customRange == null
                    ? 'Select a date range'
                    : '${formatDate(customRange!.start)}  →  ${formatDate(customRange!.end)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: subColor),
          ],
        ),
      ),
    );

    if (customRange == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          pickerButton,
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(Icons.date_range_rounded, size: 48, color: subColor),
                const SizedBox(height: 12),
                Text(
                  'Pick a date range to see\nyour earnings breakdown',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: subColor),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return FutureBuilder<List<DeliveredTrip>>(
      future: customTripsFuture,
      builder: (context, snapshot) {
        if (customLoading || snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: accent),
                const SizedBox(height: 12),
                Text('Loading earnings…', style: TextStyle(color: subColor, fontSize: 13)),
              ],
            ),
          );
        }

        final trips = snapshot.data ?? const [];
        final total = trips.fold<double>(0, (s, t) => s + t.amount);
        final (amounts, labels) = bucketByDate(trips, customRange!);
        final rangeDays =
            customRange!.end.difference(customRange!.start).inDays + 1;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            pickerButton,
            const SizedBox(height: 16),
            // Hero card — matches _EarningsTab style
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${formatDate(customRange!.start)} – ${formatDate(customRange!.end)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'QAR ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFFF0F0F0), letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${trips.length} trip${trips.length == 1 ? '' : 's'} · $rangeDays day${rangeDays == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (trips.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 36, color: subColor),
                    const SizedBox(height: 10),
                    Text('No deliveries in this range', style: TextStyle(color: subColor)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Earnings Overview',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: textColor),
                    ),
                    const SizedBox(height: 16),
                    _LabelledBarChart(
                      amounts: amounts,
                      labels: labels,
                      isDark: isDark,
                      accent: accent,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

// ─── Bar chart with external date labels ─────────────────────────────────────

class _LabelledBarChart extends StatefulWidget {
  final List<int> amounts;
  final List<String> labels;
  final bool isDark;
  final Color accent;
  const _LabelledBarChart({
    required this.amounts,
    required this.labels,
    required this.isDark,
    required this.accent,
  });

  @override
  State<_LabelledBarChart> createState() => _LabelledBarChartState();
}

class _LabelledBarChartState extends State<_LabelledBarChart> {
  int? _selected;

  void _selectFromDx(double dx, double width) {
    if (width <= 0 || widget.amounts.isEmpty) return;
    final gap = width / widget.amounts.length;
    final index = (dx / gap).floor().clamp(0, widget.amounts.length - 1);
    setState(() => _selected = _selected == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final subColor = widget.isDark ? AppColors.darkSubText : AppColors.lightSubText;

    // Only show every Nth label to avoid overlap when there are many bars.
    final count = widget.labels.length;
    final stride = count <= 7
        ? 1
        : count <= 14
            ? 2
            : count <= 31
                ? 4
                : 1; // weekly grouped — all labels shown

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
                      '${widget.labels[_selected!]} · QAR ${widget.amounts[_selected!]}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: widget.accent),
                    ),
                  ),
                ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _selectFromDx(d.localPosition.dx, constraints.maxWidth),
            child: CustomPaint(
              painter: _BarChartPainter(
                data: widget.amounts,
                accent: widget.accent,
                selectedIndex: _selected,
              ),
              child: const SizedBox(height: 100, width: double.infinity),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (i) {
            final show = i % stride == 0 || i == count - 1;
            return Expanded(
              child: Text(
                show ? widget.labels[i] : '',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 8, color: subColor),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<int> data;
  final Color accent;
  final int? selectedIndex;
  _BarChartPainter({
    required this.data,
    required this.accent,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxVal == 0) return;
    final barW = size.width / (data.length * 1.6);
    final gap = size.width / data.length;
    final hasSelection = selectedIndex != null;

    for (var i = 0; i < data.length; i++) {
      if (data[i] == 0) continue;
      // Active bar = green; inactive (when something else is selected) = dim gray.
      final isActive = !hasSelection || selectedIndex == i;
      final color = isActive ? AppColors.green : const Color(0xFF2D2D2D);
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = color;
      final h = (data[i] / maxVal) * size.height;
      final x = i * gap + (gap - barW) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barW, h),
          const Radius.circular(4),
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data || old.accent != accent || old.selectedIndex != selectedIndex;
}

