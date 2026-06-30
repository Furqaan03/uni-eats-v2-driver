import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../services/firestore_order_service.dart';
import '../earnings/widgets/date_range_sheet.dart';

/// Date-range presets for the history list. Custom opens the shared
/// [showDateRangeSheet] picker.
enum _RangePreset { today, week, month, custom }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();

  /// 0 = All, 1 = Completed, 2 = Cancelled. Outcome axis only — date range and
  /// search are separate, orthogonal controls.
  int _outcomeFilter = 0;
  static const _outcomes = ['All', 'Completed', 'Cancelled'];

  _RangePreset _preset = _RangePreset.month;
  DateTimeRange? _customRange;

  late Future<List<DeliveredTrip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _tripsFuture = _fetch();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Resolves the active preset to a concrete [DateTimeRange], snapped to whole
  /// days so the Firestore bounds are inclusive of the edge dates.
  DateTimeRange get _range {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_preset) {
      case _RangePreset.today:
        return DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: endOfToday);
      case _RangePreset.week:
        return DateTimeRange(
            start: DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 6)),
            end: endOfToday);
      case _RangePreset.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: endOfToday);
      case _RangePreset.custom:
        final r = _customRange;
        if (r == null) {
          return DateTimeRange(
              start: DateTime(now.year, now.month, 1), end: endOfToday);
        }
        return DateTimeRange(
          start: DateTime(r.start.year, r.start.month, r.start.day),
          end: DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59),
        );
    }
  }

  Future<List<DeliveredTrip>> _fetch() {
    final r = _range;
    return FirestoreOrderService.instance.fetchTripRecords(kDriverId, r.start, r.end);
  }

  void _reload() => setState(() => _tripsFuture = _fetch());

  Future<void> _refresh() async {
    _reload();
    await _tripsFuture;
  }

  Future<void> _selectPreset(_RangePreset p) async {
    if (p == _RangePreset.custom) {
      final picked = await showDateRangeSheet(context, initialRange: _customRange);
      if (picked == null || !mounted) return;
      setState(() {
        _customRange = picked;
        _preset = _RangePreset.custom;
      });
    } else {
      setState(() => _preset = p);
    }
    _reload();
  }

  String _rangeLabel(_RangePreset p) {
    switch (p) {
      case _RangePreset.today:
        return 'Today';
      case _RangePreset.week:
        return 'This Week';
      case _RangePreset.month:
        return 'This Month';
      case _RangePreset.custom:
        final r = _customRange;
        if (r == null) return 'Custom';
        return '${_shortDate(r.start)} – ${_shortDate(r.end)}';
    }
  }

  static String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
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
              t.dropoff.toLowerCase().contains(query) ||
              t.orderNumber.toLowerCase().contains(query))
          .toList();
    }
    switch (_outcomeFilter) {
      case 1: // Completed
        result = result.where((t) => t.isDelivered).toList();
      case 2: // Cancelled (vendor-cancelled + driver-abandoned)
        result = result.where((t) => t.isCancelled).toList();
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
    // light backgrounds, but invisible against dark ones. Use a visible accent.
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
            // Date-range presets (time axis)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  for (final p in _RangePreset.values) ...[
                    _RangeChip(
                      label: _rangeLabel(p),
                      icon: p == _RangePreset.custom ? Icons.calendar_today_rounded : null,
                      active: _preset == p,
                      isDark: isDark,
                      accent: accent,
                      cardBg: cardBg,
                      subText: subText,
                      onTap: () => _selectPreset(p),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Outcome tabs (status axis)
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _outcomes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final active = _outcomeFilter == i;
                  return GestureDetector(
                    onTap: () => setState(() => _outcomeFilter = i),
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
                        _outcomes[i],
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
                      return _EmptyState(
                        message: 'Could not load trip history.',
                        subText: subText,
                      );
                    }
                    final filtered = _applyFilters(snapshot.data ?? const []);
                    if (filtered.isEmpty) {
                      return _EmptyState(
                        message: _searchCtrl.text.isNotEmpty
                            ? 'No trips match "${_searchCtrl.text}".'
                            : 'No trips in this period yet.',
                        subText: subText,
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

/// Colors + label for a trip outcome badge.
({Color color, String label}) _outcomeStyle(DeliveredTrip t) {
  switch (t.outcome) {
    case TripOutcome.delivered:
      return (color: AppColors.green, label: 'Delivered');
    case TripOutcome.cancelled:
      return (color: AppColors.red, label: 'Cancelled');
    case TripOutcome.abandoned:
      return (color: AppColors.yellow, label: 'Abandoned');
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final bool isDark;
  final Color accent;
  final Color cardBg;
  final Color subText;
  final VoidCallback onTap;
  const _RangeChip({
    required this.label,
    this.icon,
    required this.active,
    required this.isDark,
    required this.accent,
    required this.cardBg,
    required this.subText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? (isDark ? AppColors.darkBg : Colors.white) : subText;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final Color subText;
  const _EmptyState({required this.message, required this.subText});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(message, style: TextStyle(fontSize: 13, color: subText)),
          ),
        ),
      ],
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

  String get _timeLabel => _formatTime(trip.deliveredAt);

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TripDetailSheet(trip: trip, isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final subTextColor = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final style = _outcomeStyle(trip);
    final startDot = trip.isDelivered ? accent : style.color;
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
                  decoration: BoxDecoration(shape: BoxShape.circle, color: startDot),
                ),
                Container(width: 1, height: 20, color: dividerColor),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: style.color),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.restaurant,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
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
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trip.isDelivered ? 'QAR ${trip.amount.toStringAsFixed(2)}' : '—',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: trip.isDelivered ? AppColors.green : subTextColor,
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
                        color: style.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        style.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: style.color,
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

class _TripDetailSheet extends StatelessWidget {
  final DeliveredTrip trip;
  final bool isDark;
  const _TripDetailSheet({required this.trip, required this.isDark});

  static const _supportEmail = 'support@unieats.qa';

  Color get _text => isDark ? AppColors.darkText : AppColors.lightText;
  Color get _sub => isDark ? AppColors.darkSubText : AppColors.lightSubText;

  String get _durationLabel {
    final mins = trip.tripDuration.inMinutes;
    if (mins < 1) return '<1 min';
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  Future<void> _copyOrderNumber(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: trip.orderNumber));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${trip.orderNumber}'), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _reportIssue(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Trip issue — ${trip.orderNumber}',
        'body': 'Order: ${trip.orderNumber}\n'
            'Restaurant: ${trip.restaurant}\n'
            'Dropoff: ${trip.dropoff}\n'
            'Date: ${_formatDateTime(trip.deliveredAt)}\n\n'
            'Describe the issue:\n',
      },
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No email app found. Reach us at $_supportEmail')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _outcomeStyle(trip);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: _sub.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.restaurant,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _text),
                      ),
                      const SizedBox(height: 2),
                      Text(trip.orderNumber, style: TextStyle(fontSize: 12, color: _sub)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    style.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: style.color),
                  ),
                ),
              ],
            ),
            // Cancellation reason banner
            if (trip.isCancelled && (trip.cancelReason?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trip.outcome == TripOutcome.abandoned
                      ? 'You gave up this order: ${trip.cancelReason}'
                      : 'Cancelled: ${trip.cancelReason}',
                  style: TextStyle(fontSize: 12, color: _text, height: 1.3),
                ),
              ),
            ],
            // Incident flags
            if (trip.hasIncidentFlags) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (trip.customerUnreachable)
                    _FlagChip(label: 'Customer unreachable', color: AppColors.red),
                  if (trip.runningLate)
                    _FlagChip(label: 'Ran late', color: AppColors.yellow),
                  if (trip.driverIncident)
                    _FlagChip(
                      label: trip.driverIncidentReason?.isNotEmpty ?? false
                          ? 'Incident: ${trip.driverIncidentReason}'
                          : 'Incident reported',
                      color: AppColors.red,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            // Route
            _SectionLabel('Route', color: _sub),
            const SizedBox(height: 10),
            _RouteBlock(
              pickup: trip.restaurant,
              dropoff: trip.dropoff,
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            // Items
            if (trip.items.isNotEmpty) ...[
              _SectionLabel(
                'Items (${trip.itemCount})',
                color: _sub,
              ),
              const SizedBox(height: 8),
              ...trip.items.map((i) => _ItemRow(item: i, isDark: isDark)),
              const SizedBox(height: 18),
            ],
            // Timeline
            _SectionLabel('Timeline', color: _sub),
            const SizedBox(height: 10),
            _DetailRow(label: 'Placed at', value: _formatDateTime(trip.placedAt), isDark: isDark),
            const SizedBox(height: 10),
            _DetailRow(
              label: '${style.label} at',
              value: _formatDateTime(trip.deliveredAt),
              isDark: isDark,
            ),
            if (trip.isDelivered) ...[
              const SizedBox(height: 10),
              _DetailRow(label: 'Trip duration', value: _durationLabel, isDark: isDark),
            ],
            const SizedBox(height: 18),
            // Customer
            _SectionLabel('Customer', color: _sub),
            const SizedBox(height: 10),
            _DetailRow(label: 'Name', value: trip.customerName, isDark: isDark),
            const Divider(height: 28),
            // Money
            _DetailRow(
              label: 'Order value',
              value: 'QAR ${trip.orderTotal.toStringAsFixed(2)}',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Your payout',
              value: trip.isDelivered
                  ? 'QAR ${trip.amount.toStringAsFixed(2)}'
                  : 'No payout',
              isDark: isDark,
              valueColor: trip.isDelivered ? AppColors.green : _sub,
            ),
            const SizedBox(height: 20),
            // Actions
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy order #',
                    isDark: isDark,
                    onTap: () => _copyOrderNumber(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.support_agent_rounded,
                    label: 'Report an issue',
                    isDark: isDark,
                    onTap: () => _reportIssue(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _RouteBlock extends StatelessWidget {
  final String pickup;
  final String dropoff;
  final bool isDark;
  const _RouteBlock({required this.pickup, required this.dropoff, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final sub = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final divider = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.storefront_rounded, size: 16, color: AppColors.green),
            Container(width: 1, height: 22, color: divider),
            Icon(Icons.location_on_rounded, size: 16, color: AppColors.red),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pickup', style: TextStyle(fontSize: 10, color: sub)),
              const SizedBox(height: 1),
              Text(pickup, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text)),
              const SizedBox(height: 14),
              Text('Dropoff', style: TextStyle(fontSize: 10, color: sub)),
              const SizedBox(height: 1),
              Text(dropoff, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  const _ItemRow({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final sub = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final qty = (item['qty'] as num?)?.toInt() ?? 1;
    final name = item['name']?.toString() ?? 'Item';
    final price = (item['price'] as num?)?.toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$qty×', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: sub)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: text)),
          ),
          if (price != null)
            Text('QAR ${price.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: sub)),
        ],
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _FlagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: text),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text)),
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
  final Color? valueColor;
  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

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
              color: valueColor ?? (isDark ? AppColors.darkText : AppColors.lightText),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final period = t.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}

String _formatDateTime(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${_formatTime(d)}';
}
