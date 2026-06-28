import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// A custom date range picker presented as a bottom sheet.
/// Returns a [DateTimeRange] when the user taps Apply, or null on dismiss.
Future<DateTimeRange?> showDateRangeSheet(
  BuildContext context, {
  DateTimeRange? initialRange,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DateRangeSheet(initialRange: initialRange),
  );
}

class _DateRangeSheet extends StatefulWidget {
  final DateTimeRange? initialRange;
  const _DateRangeSheet({this.initialRange});

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  late PageController _pageCtrl;
  // Page 0 = current month; page increases going forward, decreases going back.
  // We anchor at page 600 so there's room to scroll in both directions.
  static const _anchorPage = 600;

  DateTime? _start;
  DateTime? _end;

  // The month shown is derived from _anchorPage offset + current page.
  late DateTime _anchorMonth;
  int _currentPage = _anchorPage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorMonth = DateTime(now.year, now.month);
    _pageCtrl = PageController(initialPage: _anchorPage);

    if (widget.initialRange != null) {
      _start = _stripTime(widget.initialRange!.start);
      _end = _stripTime(widget.initialRange!.end);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _monthForPage(int page) {
    final delta = page - _anchorPage;
    var year = _anchorMonth.year;
    var month = _anchorMonth.month + delta;
    while (month > 12) { month -= 12; year++; }
    while (month < 1)  { month += 12; year--; }
    return DateTime(year, month);
  }

  void _onDayTap(DateTime day) {
    if (day.isAfter(DateTime.now())) return;
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        // Start fresh selection
        _start = day;
        _end = null;
      } else {
        // We have a start, picking end
        if (day.isBefore(_start!)) {
          // Tapping before start = restart selection from this day
          _start = day;
          _end = null;
        } else {
          // Same day or later — allow single-day range (end == start)
          _end = day;
        }
      }
    });
  }

  void _applyPreset(DateTimeRange range) {
    setState(() {
      _start = _stripTime(range.start);
      _end = _stripTime(range.end);
    });
  }

  bool _isInRange(DateTime day) {
    if (_start == null || _end == null) return false;
    return day.isAfter(_start!) && day.isBefore(_end!);
  }

  bool _isStart(DateTime day) => _start != null && day == _start;
  bool _isEnd(DateTime day) => _end != null && day == _end;

  String _formatShort(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canApply = _start != null && _end != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle + header
            _buildHeader(),
            // Quick presets
            _buildPresets(now),
            // Month navigator + calendar (expands)
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (p) => setState(() => _currentPage = p),
                itemBuilder: (_, page) {
                  final month = _monthForPage(page);
                  return _CalendarMonth(
                    month: month,
                    start: _start,
                    end: _end,
                    now: now,
                    onDayTap: _onDayTap,
                    isInRange: _isInRange,
                    isStart: _isStart,
                    isEnd: _isEnd,
                  );
                },
              ),
            ),
            // Month navigation row
            _buildMonthNav(),
            // Selection summary + apply button
            _buildFooter(canApply),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Text(
                'Select Range',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF0F0F0),
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              if (_start != null || _end != null)
                GestureDetector(
                  onTap: () => setState(() { _start = null; _end = null; }),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresets(DateTime now) {
    final today = _stripTime(now);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month, 1);

    final presets = [
      ('Today', DateTimeRange(start: today, end: today)),
      ('This week', DateTimeRange(start: weekStart, end: today)),
      ('This month', DateTimeRange(start: monthStart, end: today)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: presets.map((p) {
          final (label, range) = p;
          final active = _start == _stripTime(range.start) &&
              _end == _stripTime(range.end);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _applyPreset(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.green : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? AppColors.green : const Color(0xFF2A2A2A),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF888888),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthNav() {
    final month = _monthForPage(_currentPage);
    const monthNames = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December',
    ];
    final label = '${monthNames[month.month - 1]} ${month.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pageCtrl.previousPage(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutQuart,
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: Color(0xFFAAAAAA), size: 20),
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF0F0F0),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _pageCtrl.nextPage(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutQuart,
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFAAAAAA), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool canApply) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Column(
        children: [
          // Range summary
          AnimatedOpacity(
            opacity: _start != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RangePill(
                    label: _start != null ? _formatShort(_start!) : '—',
                    filled: _start != null,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 14, color: Color(0xFF555555)),
                  ),
                  _RangePill(
                    label: _end != null ? _formatShort(_end!) : 'End date',
                    filled: _end != null,
                  ),
                ],
              ),
            ),
          ),
          // Apply button
          SizedBox(
            width: double.infinity,
            child: AnimatedOpacity(
              opacity: canApply ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: canApply
                    ? () => Navigator.of(context)
                        .pop(DateTimeRange(start: _start!, end: _end!))
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Apply',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  final String label;
  final bool filled;
  const _RangePill({required this.label, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF1A1A1A) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: filled ? const Color(0xFF2A2A2A) : const Color(0xFF1E1E1E),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: filled ? const Color(0xFFF0F0F0) : const Color(0xFF555555),
        ),
      ),
    );
  }
}

class _CalendarMonth extends StatelessWidget {
  final DateTime month;
  final DateTime? start;
  final DateTime? end;
  final DateTime now;
  final ValueChanged<DateTime> onDayTap;
  final bool Function(DateTime) isInRange;
  final bool Function(DateTime) isStart;
  final bool Function(DateTime) isEnd;

  const _CalendarMonth({
    required this.month,
    required this.start,
    required this.end,
    required this.now,
    required this.onDayTap,
    required this.isInRange,
    required this.isStart,
    required this.isEnd,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    // weekday: 1=Mon, 7=Sun. We want Sunday first (index 0).
    final startOffset = (firstDay.weekday % 7); // Sun=0, Mon=1, ...
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    const dayHeaders = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Day-of-week headers
          Row(
            children: dayHeaders
                .map((h) => Expanded(
                      child: Center(
                        child: Text(
                          h,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          for (var row = 0; row < rows; row++)
            _CalendarRow(
              row: row,
              startOffset: startOffset,
              daysInMonth: daysInMonth,
              month: month,
              now: now,
              start: start,
              end: end,
              onDayTap: onDayTap,
              isInRange: isInRange,
              isStart: isStart,
              isEnd: isEnd,
            ),
        ],
      ),
    );
  }
}

class _CalendarRow extends StatelessWidget {
  final int row;
  final int startOffset;
  final int daysInMonth;
  final DateTime month;
  final DateTime now;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onDayTap;
  final bool Function(DateTime) isInRange;
  final bool Function(DateTime) isStart;
  final bool Function(DateTime) isEnd;

  const _CalendarRow({
    required this.row,
    required this.startOffset,
    required this.daysInMonth,
    required this.month,
    required this.now,
    required this.start,
    required this.end,
    required this.onDayTap,
    required this.isInRange,
    required this.isStart,
    required this.isEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: List.generate(7, (col) {
          final cellIndex = row * 7 + col;
          final dayNum = cellIndex - startOffset + 1;

          if (dayNum < 1 || dayNum > daysInMonth) {
            return const Expanded(child: SizedBox());
          }

          final day = DateTime(month.year, month.month, dayNum);
          final today = DateTime(now.year, now.month, now.day);
          final isFuture = day.isAfter(today);
          final inRange = isInRange(day);
          final startSel = isStart(day);
          final endSel = isEnd(day);
          final isToday = day == today;

          // Range row background tint — spans the full cell width for a
          // continuous strip between start and end endpoints.
          final showRangeBg = inRange ||
              (startSel && end != null) ||
              (endSel && start != null);

          // Which side of the range strip should be clipped
          final clipLeft = startSel && end != null;
          final clipRight = endSel && start != null;

          return Expanded(
            child: GestureDetector(
              onTap: isFuture ? null : () => onDayTap(day),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Range strip background
                  if (showRangeBg)
                    Positioned.fill(
                      child: Container(
                        margin: EdgeInsets.only(
                          left: clipLeft ? 20 : 0,
                          right: clipRight ? 20 : 0,
                        ),
                        color: AppColors.green.withValues(alpha: 0.14),
                      ),
                    ),
                  // Day circle (start/end endpoints)
                  if (startSel || endSel)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  // Today dot
                  if (isToday && !startSel && !endSel)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  // Day number
                  Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: (startSel || endSel)
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isFuture
                          ? const Color(0xFF333333)
                          : (startSel || endSel)
                              ? Colors.white
                              : inRange
                                  ? const Color(0xFFCCCCCC)
                                  : const Color(0xFFF0F0F0),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
