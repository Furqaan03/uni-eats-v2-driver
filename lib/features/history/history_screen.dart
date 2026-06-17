import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  int _activeFilter = 0;

  static const _filters = ['All', 'Completed', 'Cancelled', 'This Week'];

  final _days = [
    _DayGroup(date: 'Today, Jun 17', trips: [
      _Trip(from: 'Campus Kitchen', to: 'Dorm Block C', amount: 18.50, time: '2:14 PM', status: 'completed'),
      _Trip(from: 'Spice Garden', to: 'Library Plaza', amount: 14.00, time: '1:02 PM', status: 'completed'),
      _Trip(from: 'Café Bliss', to: 'Engineering Block', amount: 22.00, time: '11:45 AM', status: 'cancelled'),
    ]),
    _DayGroup(date: 'Yesterday, Jun 16', trips: [
      _Trip(from: 'Noodle House', to: 'Admin Block', amount: 19.00, time: '6:30 PM', status: 'completed'),
      _Trip(from: 'Burger Stop', to: 'Gym Entrance', amount: 21.00, time: '3:10 PM', status: 'completed'),
      _Trip(from: 'Campus Kitchen', to: 'Science Block', amount: 16.00, time: '12:45 PM', status: 'completed'),
    ]),
    _DayGroup(date: 'Mon, Jun 15', trips: [
      _Trip(from: 'Boba Tea', to: 'Student Union', amount: 11.00, time: '5:20 PM', status: 'completed'),
      _Trip(from: 'Pizza Hub', to: 'Dorm Block A', amount: 23.50, time: '7:15 PM', status: 'completed'),
    ]),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;

    final filtered = _activeFilter == 0
        ? _days
        : _days.map((d) {
            final status = _filters[_activeFilter].toLowerCase();
            return _DayGroup(
              date: d.date,
              trips: d.trips.where((t) => t.status == status || status == 'this week').toList(),
            );
          }).where((d) => d.trips.isNotEmpty).toList();

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
                        color: active ? AppColors.orange : cardBg,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: active
                              ? AppColors.orange
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
                          color: active ? Colors.white : subText,
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
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final day = filtered[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 4),
                        child: Text(
                          day.date,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: subText,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      ...day.trips.map(
                        (t) => _TripCard(trip: t, isDark: isDark, cardBg: cardBg),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayGroup {
  final String date;
  final List<_Trip> trips;
  const _DayGroup({required this.date, required this.trips});
}

class _Trip {
  final String from;
  final String to;
  final double amount;
  final String time;
  final String status;
  const _Trip({
    required this.from,
    required this.to,
    required this.amount,
    required this.time,
    required this.status,
  });
}

class _TripCard extends StatelessWidget {
  final _Trip trip;
  final bool isDark;
  final Color cardBg;
  const _TripCard({required this.trip, required this.isDark, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    final cancelled = trip.status == 'cancelled';
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
          // Route dots
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orange,
                ),
              ),
              Container(
                  width: 1,
                  height: 20,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cancelled ? AppColors.red : AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.from,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  trip.to,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                cancelled ? '—' : 'QAR ${trip.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: cancelled ? AppColors.red : AppColors.green,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    trip.time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.darkSubText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cancelled
                          ? AppColors.red.withValues(alpha: 0.12)
                          : AppColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cancelled ? 'Cancelled' : 'Done',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: cancelled ? AppColors.red : AppColors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
