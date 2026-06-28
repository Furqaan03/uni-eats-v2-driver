import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/driver_auth_provider.dart';
import '../../core/providers/driver_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final driver = context.watch<DriverProvider>();
    final profile = context.watch<DriverAuthProvider>().profile;
    final themeP = context.watch<ThemeProvider>();
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
        children: [
          // Hero header — uses outer SafeArea so no inner SafeArea needed
          Container(
            height: 220,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF252525),
                        border: Border.all(color: AppColors.green, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.3),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                        child: const Center(
                          child: Text('👤', style: TextStyle(fontSize: 38)),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.green,
                          ),
                          child: const Center(
                            child: Text('✓',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    profile?.name ?? 'Driver',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profile != null ? 'Driver ID: ${profile.id.substring(0, profile.id.length.clamp(0, 8))}' : '',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCol(value: driver.rating.toStringAsFixed(2), label: 'Rating', icon: '⭐'),
                _vDivider(isDark),
                _StatCol(value: '${profile?.totalTripsAllTime ?? driver.todayTrips}', label: 'Total Trips', icon: '🛵'),
                _vDivider(isDark),
                _StatCol(value: '${driver.acceptanceRate}%', label: 'Acceptance', icon: '✅'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Online status bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _OnlineBar(isDark: isDark, driver: driver),
          ),
          const SizedBox(height: 20),
          // Personal info
          _SectionCard(
            isDark: isDark,
            cardBg: cardBg,
            title: 'Personal Info',
            children: [
              _InfoRow(icon: Icons.person_outline, label: profile?.name ?? '—', isDark: isDark),
              _InfoRow(icon: Icons.phone_outlined, label: profile?.phone ?? '—', isDark: isDark),
              _InfoRow(icon: Icons.email_outlined, label: profile?.email ?? '—', isDark: isDark),
              _InfoRow(icon: Icons.school_outlined, label: profile?.campus ?? '—', isDark: isDark),
            ],
          ),
          const SizedBox(height: 14),
          // Documents
          _SectionCard(
            isDark: isDark,
            cardBg: cardBg,
            title: 'Documents',
            children: [
              _DocRow(label: 'QID', status: 'verified', isDark: isDark),
              _DocRow(label: 'Student ID', status: 'verified', isDark: isDark),
              _DocRow(label: 'Class Schedule', status: 'pending', isDark: isDark),
              _DocRow(label: 'CV / Resume', status: 'pending', isDark: isDark),
            ],
          ),
          const SizedBox(height: 14),
          // Ratings breakdown
          _SectionCard(
            isDark: isDark,
            cardBg: cardBg,
            title: 'Ratings',
            children: [
              _RatingBar(stars: 5, count: 182, total: 210, isDark: isDark),
              _RatingBar(stars: 4, count: 20, total: 210, isDark: isDark),
              _RatingBar(stars: 3, count: 5, total: 210, isDark: isDark),
              _RatingBar(stars: 2, count: 2, total: 210, isDark: isDark),
              _RatingBar(stars: 1, count: 1, total: 210, isDark: isDark),
            ],
          ),
          const SizedBox(height: 14),
          // Bank payout
          _SectionCard(
            isDark: isDark,
            cardBg: cardBg,
            title: 'Payout',
            children: [
              _InfoRow(icon: Icons.account_balance_outlined, label: 'Qatar National Bank', isDark: isDark),
              _InfoRow(icon: Icons.credit_card_outlined, label: '**** **** **** 4291', isDark: isDark),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Update Bank Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // More menu
          _SectionCard(
            isDark: isDark,
            cardBg: cardBg,
            title: 'More',
            children: [
              _MenuRow(icon: Icons.dark_mode_outlined, label: 'Dark Mode', isDark: isDark,
                  trailing: Switch(
                    value: themeP.isDark,
                    onChanged: (_) => themeP.toggle(),
                    activeThumbColor: AppColors.green,
                    activeTrackColor: AppColors.green.withValues(alpha: 0.4),
                  )),
              _MenuRow(icon: Icons.help_outline, label: 'Help & Support', isDark: isDark),
              _MenuRow(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', isDark: isDark),
              _MenuRow(icon: Icons.info_outline, label: 'App Version 1.0.0', isDark: isDark,
                  textColor: subText),
            ],
          ),
          const SizedBox(height: 14),
          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log Out?'),
                    content: const Text('You\'ll need to sign in again to receive orders.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Log Out', style: TextStyle(color: AppColors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                await context.read<DriverAuthProvider>().signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
                  (route) => false,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
        ),
      ),
    );
  }

  Widget _vDivider(bool isDark) => Container(
        width: 1,
        height: 40,
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      );
}

class _StatCol extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  const _StatCol({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.darkText : AppColors.lightText)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.darkSubText)),
      ],
    );
  }
}

class _OnlineBar extends StatelessWidget {
  final bool isDark;
  final DriverProvider driver;
  const _OnlineBar({required this.isDark, required this.driver});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (driver.isOnline && !driver.canGoOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(DriverProvider.cannotGoOfflineMessage)),
          );
          return;
        }
        if (driver.isOnline) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Go Offline?'),
              content: const Text('You will stop receiving new orders.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Go Offline', style: TextStyle(color: AppColors.red)),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
        }
        driver.toggleOnline();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: driver.isOnline
              ? AppColors.green.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: driver.isOnline
                ? AppColors.green.withValues(alpha: 0.4)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: driver.isOnline ? AppColors.green : AppColors.darkSubText,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              driver.isOnline ? 'You are Online' : 'You are Offline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: driver.isOnline
                    ? AppColors.green
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ),
            const Spacer(),
            Text(
              driver.isOnline ? 'Tap to go offline' : 'Tap to go online',
              style: const TextStyle(fontSize: 11, color: AppColors.darkSubText),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final Color cardBg;
  final String title;
  final List<Widget> children;
  const _SectionCard({
    required this.isDark,
    required this.cardBg,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
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
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  const _InfoRow({required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.darkSubText),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final String label;
  final String status;
  final bool isDark;
  const _DocRow({required this.label, required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final verified = status == 'verified';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(verified ? '📄' : '📋', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                )),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: verified
                  ? AppColors.green.withValues(alpha: 0.12)
                  : AppColors.yellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              verified ? 'Verified' : 'Pending',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: verified ? AppColors.green : AppColors.yellow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final int stars;
  final int count;
  final int total;
  final bool isDark;
  const _RatingBar({
    required this.stars,
    required this.count,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$stars', style: const TextStyle(fontSize: 12, color: AppColors.darkSubText)),
          const SizedBox(width: 4),
          const Text('⭐', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$count',
              style: const TextStyle(fontSize: 11, color: AppColors.darkSubText)),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Widget? trailing;
  final Color? textColor;
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.isDark,
    this.trailing,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor ?? AppColors.darkSubText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor ?? (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ),
          ),
          trailing ??
              Icon(Icons.chevron_right,
                  size: 18,
                  color: isDark ? AppColors.darkSubText : AppColors.lightSubText),
        ],
      ),
    );
  }
}
