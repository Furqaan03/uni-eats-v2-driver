import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/providers/driver_auth_provider.dart';
import '../../core/providers/driver_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../services/firestore_order_service.dart';
import '../../services/order_statement_service.dart';
import '../auth/login_screen.dart';
import 'help_support_screen.dart';
import 'policies.dart';
import 'policy_viewer_screen.dart';

/// Mode-aware color set, resolved once per build and threaded through the
/// child widgets. Centralizing this is what makes the screen read correctly
/// in BOTH light and dark mode — colors are never hardcoded to one theme.
class _Palette {
  final bool isDark;
  final Color bg;
  final Color surface;
  final Color text;
  final Color sub;
  final Color border;
  const _Palette({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.text,
    required this.sub,
    required this.border,
  });

  factory _Palette.of(bool isDark) => _Palette(
        isDark: isDark,
        bg: isDark ? AppColors.darkBg : AppColors.lightBg,
        surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        text: isDark ? AppColors.darkText : AppColors.lightText,
        sub: isDark ? AppColors.darkSubText : AppColors.lightSubText,
        border: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _generatingStatement = false;
  bool _uploadingPhoto = false;
  String? _busyDocKey; // document currently uploading
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (_) {
      if (mounted) setState(() => _version = '—');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- Profile photo -------------------------------------------------------

  Future<void> _changePhoto() async {
    final source = await _pickImageSource();
    if (source == null) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    final err = await context.read<DriverAuthProvider>().updateProfilePhoto(File(picked.path));
    if (mounted) setState(() => _uploadingPhoto = false);
    _toast(err ?? 'Profile photo updated.');
  }

  Future<ImageSource?> _pickImageSource() {
    final p = _Palette.of(Theme.of(context).brightness == Brightness.dark);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetTitle('Update Photo', p),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: p.text),
              title: Text('Take a photo', style: TextStyle(color: p.text)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: p.text),
              title: Text('Choose from gallery', style: TextStyle(color: p.text)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---- Documents -----------------------------------------------------------

  Future<void> _openDocument(String docKey, String label, String status) async {
    final p = _Palette.of(Theme.of(context).brightness == Brightness.dark);
    final verified = status == 'verified';
    final action = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: p.text)),
                  ),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _docStatusBlurb(status),
                style: TextStyle(fontSize: 13, height: 1.4, color: p.sub),
              ),
              const SizedBox(height: 18),
              if (!verified)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(status == 'rejected' || status == 'pending'
                        ? 'Resubmit document'
                        : 'Upload document'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == true) await _submitDocument(docKey);
  }

  Future<void> _submitDocument(String docKey) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _busyDocKey = docKey);
    final err = await context.read<DriverAuthProvider>().submitDocument(docKey, File(picked.path));
    if (mounted) setState(() => _busyDocKey = null);
    _toast(err ?? 'Document submitted for review.');
  }

  String _docStatusBlurb(String status) {
    switch (status) {
      case 'verified':
        return 'This document has been verified. No action needed.';
      case 'rejected':
        return 'This document was rejected. Upload a clearer copy to try again.';
      case 'pending':
        return 'This document is under review. You can resubmit if you uploaded the wrong file.';
      default:
        return 'This document hasn\'t been submitted yet. Upload it to get verified.';
    }
  }

  // ---- Bank details --------------------------------------------------------

  Future<void> _editBankDetails(DriverAuthProvider auth) async {
    final p = _Palette.of(Theme.of(context).brightness == Brightness.dark);
    final current = auth.bankDetails;
    final nameCtrl = TextEditingController(text: current.cardName);
    final ibanCtrl = TextEditingController(text: current.iban);
    final mobileCtrl = TextEditingController(text: current.mobile);
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: p.surface,
          title: Text('Update Bank Details',
              style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(controller: nameCtrl, label: 'Full Name (on the card)', palette: p),
                const SizedBox(height: 12),
                _Field(
                  controller: ibanCtrl,
                  label: 'IBAN Number',
                  palette: p,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: mobileCtrl,
                  label: 'Mobile Number',
                  palette: p,
                  keyboardType: TextInputType.phone,
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final iban = ibanCtrl.text.trim().toUpperCase();
                final mobile = mobileCtrl.text.trim();
                if (name.isEmpty || iban.isEmpty || mobile.isEmpty) {
                  setS(() => error = 'All three fields are required.');
                  return;
                }
                // Structural check only, not a full IBAN checksum — catches the
                // obvious "typed the wrong field" mistakes.
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

  // ---- Editable text field dialog -----------------------------------------

  void _editText({
    required String title,
    required String current,
    required void Function(String) onSave,
    TextInputType? keyboardType,
  }) {
    final p = _Palette.of(Theme.of(context).brightness == Brightness.dark);
    final ctrl = TextEditingController(text: current);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
        content: _Field(controller: ctrl, label: title, palette: p, autofocus: true, keyboardType: keyboardType),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white),
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

  // ---- Statement export ----------------------------------------------------

  Future<void> _showOrderStatementPicker() async {
    final p = _Palette.of(Theme.of(context).brightness == Brightness.dark);
    final profile = context.read<DriverAuthProvider>().profile;
    if (profile == null) return;

    final choice = await showModalBottomSheet<({Duration span, String label})>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetTitle('Export Order Statement', p),
            for (final opt in const [
              (span: Duration(days: 7), label: 'Last 7 days'),
              (span: Duration(days: 30), label: 'Last 30 days'),
              (span: Duration(days: 90), label: 'Last 90 days'),
              (span: Duration(days: 3650), label: 'All time'),
            ])
              ListTile(
                leading: Icon(Icons.table_chart_outlined, color: p.text),
                title: Text(opt.label, style: TextStyle(color: p.text)),
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
      _toast('Could not generate the statement: $e');
    } finally {
      if (mounted) setState(() => _generatingStatement = false);
    }
  }

  // ---- External links ------------------------------------------------------

  /// Maps a policy document reference to a representative icon for its row.
  IconData _policyIcon(String ref) {
    switch (ref) {
      case 'UE-POL-DRV-001':
        return Icons.shield_outlined; // Driver Safety & Data Privacy
      case 'UE-POL-PRIV-001':
        return Icons.lock_outline; // Data Protection & Privacy
      case 'UE-POL-AUP-001':
        return Icons.gavel_outlined; // Acceptable Use
      case 'UE-POL-FOOD-001':
        return Icons.restaurant_outlined; // Food Safety & Handling
      case 'UE-POL-REF-001':
        return Icons.receipt_long_outlined; // Refund & Cancellation
      default:
        return Icons.description_outlined;
    }
  }


  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = _Palette.of(isDark);
    final driver = context.watch<DriverProvider>();
    final auth = context.watch<DriverAuthProvider>();
    final themeP = context.watch<ThemeProvider>();
    final profile = auth.profile;
    final bank = auth.bankDetails;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Hero(
              palette: p,
              profile: profile,
              uploading: _uploadingPhoto,
              onChangePhoto: profile == null ? null : _changePhoto,
            ),
            const SizedBox(height: 18),

            // Stats — glanceable, four columns including lifetime earnings.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _StatCol(value: driver.rating.toStringAsFixed(2), label: 'Rating', icon: Icons.star_rounded, iconColor: AppColors.yellow, palette: p),
                  _StatDivider(p),
                  _StatCol(value: '${profile?.totalTripsAllTime ?? driver.todayTrips}', label: 'Trips', icon: Icons.two_wheeler_rounded, palette: p),
                  _StatDivider(p),
                  _StatCol(value: '${driver.acceptanceRate}%', label: 'Accept', icon: Icons.check_circle_rounded, palette: p),
                  _StatDivider(p),
                  _StatCol(value: 'QAR ${(profile?.totalEarningsAllTime ?? 0).toStringAsFixed(0)}', label: 'Earned', icon: Icons.payments_rounded, palette: p),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Online status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _OnlineBar(palette: p, driver: driver),
            ),
            const SizedBox(height: 14),

            // Personal info
            _Section(
              palette: p,
              title: 'Personal Info',
              children: [
                _Row(
                  palette: p,
                  icon: Icons.person_outline,
                  label: 'Name',
                  value: profile?.name ?? '—',
                  onTap: profile == null
                      ? null
                      : () => _editText(
                            title: 'Full Name',
                            current: profile.name,
                            onSave: (v) => context.read<DriverAuthProvider>().updateProfileFields(name: v),
                          ),
                ),
                _Row(
                  palette: p,
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: profile?.phone.isNotEmpty == true ? profile!.phone : '—',
                  onTap: profile == null
                      ? null
                      : () => _editText(
                            title: 'Phone Number',
                            current: profile.phone,
                            keyboardType: TextInputType.phone,
                            onSave: (v) => context.read<DriverAuthProvider>().updateProfileFields(phone: v),
                          ),
                ),
                _Row(
                  palette: p,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: profile?.email ?? '—',
                  locked: true,
                  onTap: () => _info('Email',
                      'Your email is tied to your sign-in and can\'t be changed here. Contact support if you need it updated.'),
                ),
                _Row(
                  palette: p,
                  icon: Icons.school_outlined,
                  label: 'Campus',
                  value: profile?.campus ?? '—',
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

            // Documents — real statuses from profile.documents
            _Section(
              palette: p,
              title: 'Documents',
              children: [
                for (final doc in kDriverDocuments)
                  _DocRow(
                    palette: p,
                    label: doc.label,
                    status: profile?.documents[doc.key] ?? 'missing',
                    busy: _busyDocKey == doc.key,
                    onTap: profile == null
                        ? null
                        : () => _openDocument(doc.key, doc.label,
                            profile.documents[doc.key] ?? 'missing'),
                  ),
              ],
            ),

            // Ratings breakdown — real data with zero-state
            _Section(
              palette: p,
              title: 'Ratings',
              children: [
                if ((profile?.totalRatingCount ?? 0) == 0)
                  _EmptyState(
                    palette: p,
                    icon: Icons.star_outline_rounded,
                    message: 'No ratings yet. Complete deliveries to start earning reviews.',
                  )
                else
                  for (var star = 5; star >= 1; star--)
                    _RatingBar(
                      palette: p,
                      stars: star,
                      count: profile!.ratingBreakdown[star] ?? 0,
                      total: profile.totalRatingCount,
                    ),
              ],
            ),

            // Payout
            _Section(
              palette: p,
              title: 'Payout',
              children: [
                _Row(
                  palette: p,
                  icon: Icons.badge_outlined,
                  label: 'Name on card',
                  value: bank.cardName.isEmpty ? 'Not set' : bank.cardName,
                  onTap: () => _editBankDetails(context.read<DriverAuthProvider>()),
                ),
                _Row(
                  palette: p,
                  icon: Icons.credit_card_outlined,
                  label: 'IBAN',
                  value: bank.iban.isEmpty ? 'Not set' : _maskIban(bank.iban),
                  onTap: () => _editBankDetails(context.read<DriverAuthProvider>()),
                ),
                _Row(
                  palette: p,
                  icon: Icons.phone_iphone_outlined,
                  label: 'Mobile',
                  value: bank.mobile.isEmpty ? 'Not set' : bank.mobile,
                  onTap: () => _editBankDetails(context.read<DriverAuthProvider>()),
                ),
              ],
            ),

            // More
            _Section(
              palette: p,
              title: 'More',
              children: [
                _Row(
                  palette: p,
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark Mode',
                  trailing: Switch(
                    value: themeP.isDark,
                    onChanged: (_) => themeP.toggle(),
                    activeThumbColor: AppColors.green,
                    activeTrackColor: AppColors.green.withValues(alpha: 0.4),
                  ),
                  onTap: themeP.toggle,
                ),
                _Row(
                  palette: p,
                  icon: Icons.table_chart_outlined,
                  label: 'Order Statement',
                  value: 'Excel',
                  trailing: _generatingStatement
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: _generatingStatement ? null : _showOrderStatementPicker,
                ),
                _Row(
                  palette: p,
                  icon: Icons.help_outline,
                  label: 'Help & Support',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HelpSupportScreen(
                        driverName: profile?.name ?? '',
                        driverId: profile?.id ?? '',
                        appVersion: _version,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Legal & Policies — official Uni Eats policy documents,
            // readable offline (see policies.dart / PolicyViewerScreen).
            _Section(
              palette: p,
              title: 'Legal & Policies',
              children: [
                for (final policy in kDriverPolicies)
                  _Row(
                    palette: p,
                    icon: _policyIcon(policy.ref),
                    label: policy.title,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PolicyViewerScreen(policy: policy),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _LogoutButton(onConfirm: _logout),
            ),
            const SizedBox(height: 18),
            // App version — conventional placement at the very bottom.
            Center(
              child: Text(
                (_version.isEmpty || _version == '—')
                    ? 'Uni Eats Driver'
                    : 'Uni Eats Driver · v$_version',
                style: TextStyle(fontSize: 11.5, color: p.sub),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _info(String title, String body) {
    final p = _Palette.of(Theme.of(context).brightness == Brightness.dark);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
        content: SingleChildScrollView(child: Text(body, style: TextStyle(color: p.sub, height: 1.4))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _logout() async {
    // Wipe the in-app notification center so the next driver to sign in on this
    // device doesn't inherit these notifications.
    context.read<DriverProvider>().clearPersistedNotifications();
    await context.read<DriverAuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
      (route) => false,
    );
  }

  String _maskIban(String iban) {
    if (iban.length <= 6) return iban;
    return '${iban.substring(0, 4)} •••• ${iban.substring(iban.length - 2)}';
  }
}

// ===========================================================================
// Hero
// ===========================================================================

class _Hero extends StatelessWidget {
  final _Palette palette;
  final DriverProfile? profile;
  final bool uploading;
  final VoidCallback? onChangePhoto;
  const _Hero({required this.palette, required this.profile, required this.uploading, this.onChangePhoto});

  @override
  Widget build(BuildContext context) {
    final verified = profile?.isVerified ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.orangeDark, AppColors.darkSurface],
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onChangePhoto,
            child: Stack(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.darkCard,
                    border: Border.all(color: AppColors.green, width: 2.5),
                    boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.28), blurRadius: 18)],
                    image: profile?.photoUrl != null
                        ? DecorationImage(image: NetworkImage(profile!.photoUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: profile?.photoUrl == null
                      ? const Center(child: Icon(Icons.person, size: 44, color: Colors.white70))
                      : null,
                ),
                if (uploading)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                      child: const Center(
                        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      ),
                    ),
                  ),
                // Camera affordance — always visible so the tap target is discoverable.
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.green,
                      border: Border.all(color: AppColors.orangeDark, width: 2),
                    ),
                    child: const Icon(Icons.photo_camera, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  profile?.name ?? 'Driver',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              if (verified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 19, color: AppColors.green),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              profile != null
                  ? 'ID ${profile!.id.substring(0, profile!.id.length.clamp(0, 8))}  ·  ${profile!.campus}'
                  : '',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Stats
// ===========================================================================

class _StatCol extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? iconColor;
  final _Palette palette;
  const _StatCol({required this.value, required this.label, required this.icon, required this.palette, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor ?? palette.sub),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: palette.text)),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.sub)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final _Palette p;
  const _StatDivider(this.p);
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 34, color: p.border);
}

// ===========================================================================
// Online bar
// ===========================================================================

class _OnlineBar extends StatelessWidget {
  final _Palette palette;
  final DriverProvider driver;
  const _OnlineBar({required this.palette, required this.driver});

  @override
  Widget build(BuildContext context) {
    final online = driver.isOnline;
    return GestureDetector(
      onTap: () async {
        if (online && !driver.canGoOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(DriverProvider.cannotGoOfflineMessage)),
          );
          return;
        }
        if (online) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: palette.surface,
              title: Text('Go Offline?', style: TextStyle(color: palette.text)),
              content: Text('You will stop receiving new orders.', style: TextStyle(color: palette.sub)),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: online ? AppColors.green.withValues(alpha: 0.12) : palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: online ? AppColors.green.withValues(alpha: 0.45) : palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: online ? AppColors.green : palette.sub),
            ),
            const SizedBox(width: 12),
            Text(
              online ? 'You are Online' : 'You are Offline',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: online ? AppColors.green : palette.text,
              ),
            ),
            const Spacer(),
            Text(online ? 'Tap to go offline' : 'Tap to go online',
                style: TextStyle(fontSize: 11.5, color: palette.sub)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Section + rows
// ===========================================================================

class _Section extends StatelessWidget {
  final _Palette palette;
  final String title;
  final List<Widget> children;
  const _Section({required this.palette, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: palette.sub,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: palette.border, indent: 16, endIndent: 16),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final _Palette palette;
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool locked;
  const _Row({
    required this.palette,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48), // 44pt+ tap target
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 19, color: palette.text),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: palette.text)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value ?? '',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: palette.sub),
                ),
              ),
              if (trailing != null)
                Padding(padding: const EdgeInsets.only(left: 8), child: trailing!)
              else if (locked)
                Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.lock_outline, size: 15, color: palette.sub))
              else if (onTap != null)
                Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.chevron_right, size: 18, color: palette.sub)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final _Palette palette;
  final String label;
  final String status;
  final bool busy;
  final VoidCallback? onTap;
  const _DocRow({required this.palette, required this.label, required this.status, required this.busy, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 19, color: palette.text),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: palette.text)),
              ),
              if (busy)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                _StatusChip(status: status),
              if (onTap != null)
                Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right, size: 18, color: palette.sub)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String text;
    switch (status) {
      case 'verified':
        color = AppColors.green;
        text = 'Verified';
      case 'pending':
        color = AppColors.yellow;
        text = 'Pending';
      case 'rejected':
        color = AppColors.red;
        text = 'Rejected';
      default:
        color = AppColors.darkSubText;
        text = 'Not submitted';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final _Palette palette;
  final int stars;
  final int count;
  final int total;
  const _RatingBar({required this.palette, required this.stars, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Row(
              children: [
                Text('$stars', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.text)),
                const SizedBox(width: 2),
                const Icon(Icons.star_rounded, size: 12, color: AppColors.yellow),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: palette.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            child: Text('$count', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, color: palette.sub)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _Palette palette;
  final IconData icon;
  final String message;
  const _EmptyState({required this.palette, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Icon(icon, size: 22, color: palette.sub),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12.5, height: 1.4, color: palette.sub))),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared bits
// ===========================================================================

class _SheetTitle extends StatelessWidget {
  final String text;
  final _Palette p;
  const _SheetTitle(this.text, this.p);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.text)),
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final _Palette palette;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  const _Field({
    required this.controller,
    required this.label,
    required this.palette,
    this.autofocus = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: TextStyle(color: palette.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: palette.sub),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: palette.border)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final Future<void> Function() onConfirm;
  const _LogoutButton({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
        if (confirmed == true) await onConfirm();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Text('Log Out',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.red)),
        ),
      ),
    );
  }
}
