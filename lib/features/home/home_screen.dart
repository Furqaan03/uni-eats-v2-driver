import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/driver_provider.dart';
import '../../core/theme/theme_provider.dart';
import 'widgets/mock_map.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int)? onTabSwitch;
  const HomeScreen({super.key, this.onTabSwitch});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();
    final themeP = context.watch<ThemeProvider>();
    final isDark = themeP.isDark;

    // No inner Scaffold — MainNavShell's Scaffold provides the shell.
    // All children are Positioned so the Stack's size comes from Positioned.fill(MockMap).
    return Stack(
      children: [
        // Full-screen map
        Positioned.fill(child: MockMap(isDark: isDark)),

        // Top bar + toggle — anchored to the top edge
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row: earnings (left) + bell (right)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Earnings chip — taps to Earnings tab
                      GestureDetector(
                        onTap: () => onTabSwitch?.call(1),
                        child: _GlassChip(
                          isDark: isDark,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💰', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'QAR ${driver.todayEarnings.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right,
                                  size: 14,
                                  color: isDark ? AppColors.darkSubText : AppColors.lightSubText),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Notification bell
                      GestureDetector(
                        onTap: () => _showNotifications(context, driver, isDark),
                        child: _GlassChip(
                          isDark: isDark,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(Icons.notifications_outlined,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                  size: 20),
                              if (driver.unreadCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: AppColors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        driver.unreadCount > 9 ? '9+' : '${driver.unreadCount}',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle below the row — never overlaps
                _OnlineToggle(isDark: isDark, driver: driver),
              ],
            ),
          ),
        ),

        // Bottom stats sheet — hidden while active delivery bar occupies the bottom
        if (!driver.hasActiveDelivery)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomStatsSheet(isDark: isDark, driver: driver),
          ),
      ],
    );
  }
}

void _showNotifications(BuildContext context, DriverProvider driver, bool isDark) {
  driver.markAllRead();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Pass the provider down into the new route's context
    builder: (sheetCtx) => ChangeNotifierProvider.value(
      value: driver,
      child: _NotificationsSheet(isDark: isDark),
    ),
  );
}

Future<void> _confirmGoOffline(BuildContext context, DriverProvider driver) async {
  if (!driver.canGoOffline) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delivery in Progress',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          DriverProvider.cannotGoOfflineMessage,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Go Offline?', style: TextStyle(fontWeight: FontWeight.w800)),
      content: const Text(
        "You won't receive any new orders while offline.",
        style: TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.red),
          child: const Text('Go Offline', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  if (confirmed == true) driver.goOffline();
}

class _OnlineToggle extends StatelessWidget {
  final bool isDark;
  final DriverProvider driver;
  const _OnlineToggle({required this.isDark, required this.driver});

  @override
  Widget build(BuildContext context) {
    final online = driver.isOnline;
    final bgColor = online
        ? AppColors.green
        : (isDark ? const Color(0xFF2A2A2A) : Colors.white);
    final textColor = online
        ? Colors.white
        : (isDark ? AppColors.darkText : AppColors.lightText);

    return GestureDetector(
      onTap: () {
        if (online) {
          _confirmGoOffline(context, driver);
        } else {
          driver.toggleOnline();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: online
                  ? AppColors.green.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing status dot
            _PulsingDot(online: online),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                online ? 'Online' : 'Offline',
                key: ValueKey(online),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Toggle track
            _ToggleTrack(online: online),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final bool online;
  const _PulsingDot({required this.online});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween(begin: 0.85, end: 1.15).animate(
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
    final color = widget.online ? Colors.white : AppColors.darkSubText;
    return ScaleTransition(
      scale: widget.online ? _scale : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: widget.online
              ? [BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 6)]
              : null,
        ),
      ),
    );
  }
}

class _ToggleTrack extends StatelessWidget {
  final bool online;
  const _ToggleTrack({required this.online});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 38,
      height: 21,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: online
            ? Colors.white.withValues(alpha: 0.35)
            : AppColors.darkBorder,
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: online ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 17,
          height: 17,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? Colors.white : AppColors.darkSubText,
          ),
        ),
      ),
    );
  }
}

class _BottomStatsSheet extends StatelessWidget {
  final bool isDark;
  final DriverProvider driver;
  const _BottomStatsSheet({required this.isDark, required this.driver});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(
                  label: 'Today\'s Earnings',
                  value: 'QAR ${driver.todayEarnings.toStringAsFixed(2)}',
                  icon: '💰',
                  isDark: isDark,
                ),
                _divider(isDark),
                _Stat(
                  label: 'Trips',
                  value: '${driver.todayTrips}',
                  icon: '🛵',
                  isDark: isDark,
                ),
                _divider(isDark),
                _Stat(
                  label: 'Rating',
                  value: driver.rating.toStringAsFixed(2),
                  icon: '⭐',
                  isDark: isDark,
                ),
                _divider(isDark),
                _Stat(
                  label: 'Accept Rate',
                  value: '${driver.acceptanceRate}%',
                  icon: '✅',
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Container(
        width: 1,
        height: 40,
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final bool isDark;
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _GlassChip extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _GlassChip({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Notifications bottom sheet ───────────────────────────────────────────────
class _NotificationsSheet extends StatelessWidget {
  final bool isDark;
  const _NotificationsSheet({required this.isDark});

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Consumer<DriverProvider>(
      builder: (context, driver, _) {
        final notifications = driver.notifications;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (notifications.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${notifications.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (notifications.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          driver.clearAllNotifications();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.red,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  notifications.isEmpty
                      ? ''
                      : 'Swipe left on a notification to remove it',
                  style: TextStyle(fontSize: 10, color: subColor),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔔', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(
                              'No notifications',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You\'re all caught up',
                              style: TextStyle(fontSize: 12, color: subColor),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => Divider(
                          color: borderColor,
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                        ),
                        itemBuilder: (_, i) {
                          final n = notifications[i];
                          return Dismissible(
                            key: ValueKey(n.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => driver.removeNotification(n.id),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              color: AppColors.red.withValues(alpha: 0.12),
                              child: const Icon(
                                Icons.delete_outline,
                                color: AppColors.red,
                                size: 22,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkCard
                                          : AppColors.lightBg,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Center(
                                      child: Text(n.icon,
                                          style: const TextStyle(fontSize: 19)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          n.body,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: subColor,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _timeAgo(n.time),
                                    style: TextStyle(
                                        fontSize: 10, color: subColor),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
