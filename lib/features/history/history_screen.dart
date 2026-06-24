import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/firestore_order_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  int _activeFilter = 0;
  late Future<List<DeliveredTrip>> _tripsFuture;

  static const _filters = ['All', 'Delivery', 'Pickup', 'This Week'];

  @override
  void initState() {
    super.initState();
    _tripsFuture = FirestoreOrderService.instance
        .fetchTripHistory(kDriverId, DateTime.now().subtract(const Duration(days: 30)));
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _tripsFuture = FirestoreOrderService.instance
          .fetchTripHistory(kDriverId, DateTime.now().subtract(const Duration(days: 30)));
    });
    await _tripsFuture;
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  List<DeliveredTrip> _applyFilters(List<DeliveredTrip> trips) {
    var result = trips;
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result
          .where((t) =>
              t.restaurant.toLowerCase().contains(query) ||
              t.dropoff.toLowerCase().contains(query))
          .toList();
    }
    switch (_activeFilter) {
      case 1:
        result = result.where((t) => !t.isPickup).toList();
      case 2:
        result = result.where((t) => t.isPickup).toList();
      case 3:
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        result = result.where((t) => t.deliveredAt.isAfter(weekAgo)).toList();
    }
    return result;
  }

  Map<String, List<DeliveredTrip>> _groupByDay(List<DeliveredTrip> trips) {
    final groups = <String, List<DeliveredTrip>>{};
    for (final t in trips) {
      groups.putIfAbsent(_dayLabel(t.deliveredAt), () => []).add(t);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    // AppColors.orange is a near-black brand color — fine as an accent on
    // light backgrounds, but invisible against dark ones (same issue fixed
    // on the Earnings screen). Use a genuinely visible accent in dark mode.
    final accent = isDark ? AppColors.yellow : AppColors.orange;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                'History',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Search trips...',
                    hintStyle: TextStyle(fontSize: 14, color: subText),
                    prefixIcon: Icon(Icons.search, color: subText, size: 20),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close_rounded, color: subText, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Filter chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final active = _activeFilter == i;
                  return GestureDetector(
                    onTap: () => setState(() => _activeFilter = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? accent : cardBg,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: active
                              ? accent
                              : isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                        ),
                      ),
                      child: Text(
                        _filters[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? (isDark ? AppColors.darkBg : Colors.white)
                              : subText,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Day-grouped list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<DeliveredTrip>>(
                  future: _tripsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text('Could not load trip history.',
                                  style: TextStyle(fontSize: 13, color: subText)),
                            ),
                          ),
                        ],
                      );
                    }
                    final filtered = _applyFilters(snapshot.data ?? const []);
                    if (filtered.isEmpty) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                _searchCtrl.text.isNotEmpty
                                    ? 'No trips match "${_searchCtrl.text}".'
                                    : 'No trips in this period yet.',
                                style: TextStyle(fontSize: 13, color: subText),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    final groups = _groupByDay(filtered);
                    final dayKeys = groups.keys.toList();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: dayKeys.length,
                      itemBuilder: (_, i) {
                        final day = dayKeys[i];
                        final trips = groups[day]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10, top: 4),
                              child: Text(
                                day,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: subText,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            ...trips.map(
                              (t) => _TripCard(
                                trip: t,
                                isDark: isDark,
                                cardBg: cardBg,
                                accent: accent,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

  String get _durationLabel {
    final mins = trip.tripDuration.inMinutes;
    if (mins < 1) return '<1 min';
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60}h ${mins % 60}m';
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.restaurant,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trip.orderNumber,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                        ),
                      ),
                    ],
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
            _DetailRow(label: 'Customer', value: trip.customerName, isDark: isDark),
            const SizedBox(height: 10),
            _DetailRow(label: 'Dropoff', value: trip.dropoff, isDark: isDark),
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Order type',
              value: trip.isPickup ? 'Pickup' : 'Delivery',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Items',
              value: '${trip.itemCount} item${trip.itemCount == 1 ? '' : 's'}',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _DetailRow(label: 'Trip duration', value: _durationLabel, isDark: isDark),
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Delivered at',
              value: _timeLabel,
              isDark: isDark,
            ),
            const Divider(height: 24),
            _DetailRow(
              label: 'Your earnings',
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
            // Route dots
            Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                ),
                Container(width: 1, height: 20, color: dividerColor),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.green),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          trip.restaurant,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: subTextColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          trip.isPickup ? 'Pickup' : 'Delivery',
                          style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w700, color: subTextColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    trip.dropoff,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(_timeLabel, style: TextStyle(fontSize: 11, color: subTextColor)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _DetailRow({required this.label, required this.value, required this.isDark});

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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
      ],
    );
  }
}
