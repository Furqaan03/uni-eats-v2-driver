import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/driver_auth_provider.dart';
import '../../core/providers/driver_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../services/firestore_order_service.dart';
import '../../services/order_statement_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _generatingStatement = false;

  void _editText({
    required String title,
    required String current,
    required void Function(String) onSave,
    TextInputType? keyboardType,
  }) {
    final ctrl = TextEditingController(text: current);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: title),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) onSave(v);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editBankDetails(BuildContext context, DriverAuthProvider auth) async {
    final current = auth.bankDetails;
    final nameCtrl = TextEditingController(text: current.cardName);
    final ibanCtrl = TextEditingController(text: current.iban);
    final mobileCtrl = TextEditingController(text: current.mobile);
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Update Bank Details', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name (on the card)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ibanCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'IBAN Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final iban = ibanCtrl.text.trim().toUpperCase();
                final mobile = mobileCtrl.text.trim();
                if (name.isEmpty || iban.isEmpty || mobile.isEmpty) {
                  setS(() => error = 'All three fields are required.');
                  return;
                }
                // Basic structural check, not a full IBAN checksum — catches
                // the obvious "typed the wrong field" mistakes without being
                // overly strict about country-specific IBAN lengths.
                if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{10,30}$').hasMatch(iban)) {
                  setS(() => error = 'That doesn\'t look like a valid IBAN.');
                  return;
                }
                final err = await auth.updateBankDetails(
                  BankDetails(cardName: name, iban: iban, mobile: mobile),
                );
                if (err != null) {
                  setS(() => error = err);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOrderStatementPicker(BuildContext context) async {
    final auth = context.read<DriverAuthProvider>();
    final profile = auth.profile;
    if (profile == null) return;

    final choice = await showModalBottomSheet<({Duration span, String label})>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Export Order Statement',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
            for (final opt in [
              (span: const Duration(days: 7), label: 'Last 7 days'),
              (span: const Duration(days: 30), label: 'Last 30 days'),
              (span: const Duration(days: 90), label: 'Last 90 days'),
              (span: const Duration(days: 3650), label: 'All time'),
            ])
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: Text(opt.label),
                onTap: () => Navigator.pop(ctx, opt),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;

    setState(() => _generatingStatement = true);
    try {
      await OrderStatementService.generateAndShare(
        driverId: profile.id,
        driverName: profile.name,
        since: DateTime.now().subtract(choice.span),
        periodLabel: choice.label,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate the statement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingStatement = false);
    }
  }

  void _showDocumentDetail(BuildContext context, String label, String status) {
    final verified = status == 'verified';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          verified
              ? 'This document has been verified. No action needed.'
              : 'This document is pending review. You can resubmit it if you uploaded the wrong file.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (!verified)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resubmission flow coming soon.')),
                );
              },
              child: const Text('Resubmit'),
            ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final driver = context.watch<DriverProvider>();
    final auth = context.watch<DriverAuthProvider>();
    final profile = auth.profile;
    final bankDetails = auth.bankDetails;
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
              _InfoRow(
                icon: Icons.person_outline,
                label: profile?.name ?? '—',
                isDark: isDark,
                onTap: profile == null
                    ? null
                    : () => _editText(
                          title: 'Full Name',
                          current: profile.name,
                          onSave: (v) => context.read<DriverAuthProvider>().updateProfileFields(name: v),
                        ),
              ),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: profile?.phone ?? '—',
                isDark: isDark,
                onTap: profile == null
                    ? null
                    : () => _editText(
                          title: 'Phone Number',
                          current: profile.phone,
                          keyboardType: TextInputType.phone,
                          onSave: (v) => context.read<DriverAuthProvider>().updateProfileFields(phone: v),
                        ),
              ),
              _InfoRow(
                icon: Icons.email_outlined,
                label: profile?.email ?? '—',
                isDark: isDark,
                onTap: () => _showInfoDialog(context, 'Email',
                    'Your email is tied to your sign-in and can\'t be changed here. Contact support if you need it updated.'),
              ),
              _InfoRow(
                icon: Icons.school_outlined,
                label: profile?.campus ?? '—',
                isDark: isDark,
                onTap: profile == null
                    ? null
                    : () => _editText(
                          title: 'Campus',
                          current: profile.campus,
                          onSave: (v) => context.read<DriverAuthProvider>().updateProfileFields(campus: v),
                        ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Documents
          _SectionCard(
            isDark: isDark,
            cardBg: cardBg,
            title: 'Documents',
            children: [
              _DocRow(
                label: 'QID',
                status: 'verified',
                isDark: isDark,
                onTap: () => _showDocumentDetail(context, 'QID', 'verified'),
              ),
              _DocRow(
                label: 'Student ID',
                status: 'verified',
                isDark: isDark,
                onTap: () => _showDocumentDetail(context, 'Student ID', 'verified'),
              ),
              _DocRow(
                label: 'Class Schedule',
                status: 'pending',
                isDark: isDark,
                onTap: () => _showDocumentDetail(context, 'Class Schedule', 'pending'),
              ),
              _DocRow(
                label: 'CV / Resume',
                status: 'pending',
                isDark: isDark,
                onTap: () => _showDocumentDetail(context, 'CV / Resume', 'pending'),
              ),
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
              _InfoRow(
                icon: Icons.badge_outlined,
                label: bankDetails.cardName.isEmpty ? 'Name on card not set' : bankDetails.cardName,
                isDark: isDark,
                onTap: () => _editBankDetails(context, context.read<DriverAuthProvider>()),
              ),
              _InfoRow(
                icon: Icons.credit_card_outlined,
                label: bankDetails.iban.isEmpty ? 'IBAN not set' : _maskIban(bankDetails.iban),
                isDark: isDark,
                onTap: () => _editBankDetails(context, context.read<DriverAuthProvider>()),
              ),
              _InfoRow(
                icon: Icons.phone_iphone_outlined,
                label: bankDetails.mobile.isEmpty ? 'Mobile not set' : bankDetails.mobile,
                isDark: isDark,
                onTap: () => _editBankDetails(context, context.read<DriverAuthProvider>()),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () => _editBankDetails(context, context.read<DriverAuthProvider>()),
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
                  onTap: themeP.toggle,
                  trailing: Switch(
                    value: themeP.isDark,
                    onChanged: (_) => themeP.toggle(),
                    activeThumbColor: AppColors.green,
                    activeTrackColor: AppColors.green.withValues(alpha: 0.4),
                  )),
              _MenuRow(
                icon: Icons.table_chart_outlined,
                label: 'Order Statement (Excel)',
                isDark: isDark,
                trailing: _generatingStatement
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _generatingStatement ? null : () => _showOrderStatementPicker(context),
              ),
              _MenuRow(
                icon: Icons.help_outline,
                label: 'Help & Support',
                isDark: isDark,
                onTap: () => _showInfoDialog(context, 'Help & Support',
                    'Need help with an order, payout, or your account? Email support@unieats.qa or use the in-app chat from an active delivery.'),
              ),
              _MenuRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                isDark: isDark,
                onTap: () => _showInfoDialog(context, 'Privacy Policy',
                    'Uni Eats collects your location while online to match you with nearby orders, and your delivery history to calculate earnings and ratings. Your data is never sold to third parties.'),
              ),
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

  String _maskIban(String iban) {
    if (iban.length <= 6) return iban;
    return '${iban.substring(0, 4)} •••• •••• ${iban.substring(iban.length - 2)}';
  }
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
  final VoidCallback? onTap;
  const _InfoRow({required this.icon, required this.label, required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 16, color: AppColors.darkSubText),
          ],
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final String label;
  final String status;
  final bool isDark;
  final VoidCallback? onTap;
  const _DocRow({required this.label, required this.status, required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    final verified = status == 'verified';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
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
  final VoidCallback? onTap;
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.isDark,
    this.trailing,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
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
              (onTap != null
                  ? Icon(Icons.chevron_right,
                      size: 18,
                      color: isDark ? AppColors.darkSubText : AppColors.lightSubText)
                  : const SizedBox.shrink()),
        ],
      ),
      ),
    );
  }
}
