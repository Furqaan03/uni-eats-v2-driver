import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'help_content.dart';

/// Driver Help & Support center: campus emergency procedures, contact channels,
/// FAQ, and a context-pre-filled "report a problem" path. All content is
/// offline; only the contact actions need connectivity.
class HelpSupportScreen extends StatefulWidget {
  /// Identifying context pre-filled into support emails so ops can triage
  /// without a back-and-forth. Any may be empty if not yet loaded.
  final String driverName;
  final String driverId;
  final String appVersion;

  const HelpSupportScreen({
    super.key,
    required this.driverName,
    required this.driverId,
    required this.appVersion,
  });

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _scroll = ScrollController();
  bool _showCompactTitle = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 40;
      if (show != _showCompactTitle) setState(() => _showCompactTitle = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ---- Actions -------------------------------------------------------------

  Future<void> _launch(Uri uri, String failMsg) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _toast(failMsg);
    } catch (_) {
      if (mounted) _toast(failMsg);
    }
  }

  void _call(String tel, String failMsg) =>
      _launch(Uri(scheme: 'tel', path: tel), failMsg);

  /// Opens the mail client with driver/app context pre-filled in the body.
  void _emailSupport({required String subject}) {
    final body = StringBuffer()
      ..writeln('\n\n———')
      ..writeln('Please describe your issue above this line.')
      ..writeln('———')
      ..writeln('Driver: ${widget.driverName.isEmpty ? "—" : widget.driverName}')
      ..writeln('Driver ID: ${widget.driverId.isEmpty ? "—" : widget.driverId}')
      ..writeln('App version: ${widget.appVersion.isEmpty ? "—" : widget.appVersion}')
      ..writeln('Platform: ${Platform.operatingSystem}');
    _launch(
      Uri(
        scheme: 'mailto',
        path: kOpsEmail,
        queryParameters: {'subject': subject, 'body': body.toString()},
      ),
      'No email app found. Reach us at $kOpsEmail',
    );
  }

  void _whatsApp() => _launch(
        Uri.parse('https://wa.me/$kOpsWhatsApp'),
        'Could not open WhatsApp. Call us at $kOpsPhoneDisplay',
      );

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));

  Future<void> _copyDriverId() async {
    await Clipboard.setData(ClipboardData(text: widget.driverId));
    if (mounted) _toast('Driver ID copied');
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final sub = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accent = isDark ? AppColors.yellow : AppColors.orange;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar — back + title that fades in on scroll.
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                  bottom: BorderSide(
                    color: _showCompactTitle ? border : Colors.transparent,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: text),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _showCompactTitle ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        'Help & Support',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 18),
                    child: Text(
                      'Help & Support',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.5,
                        color: text,
                      ),
                    ),
                  ),

                  // ---- Campus emergency ----
                  _EmergencyCard(
                    isDark: isDark,
                    onCallCampus: () => _call(
                      kCampusSecurityTel,
                      'Could not start the call. Dial $kCampusSecurityDisplay.',
                    ),
                    onCallNational: () => _call(
                      kNationalEmergency,
                      'Could not start the call. Dial $kNationalEmergency.',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Contact us ----
                  _SectionLabel('Contact us', sub),
                  const SizedBox(height: 10),
                  _ContactTile(
                    icon: Icons.mail_outline_rounded,
                    title: 'Email support',
                    subtitle: kOpsEmail,
                    surface: surface,
                    border: border,
                    text: text,
                    sub: sub,
                    accent: accent,
                    onTap: () => _emailSupport(subject: 'Driver app support'),
                  ),
                  const SizedBox(height: 10),
                  _ContactTile(
                    icon: Icons.call_outlined,
                    title: 'Call operations',
                    subtitle: kOpsPhoneDisplay,
                    surface: surface,
                    border: border,
                    text: text,
                    sub: sub,
                    accent: accent,
                    onTap: () => _call(kOpsTel, 'Could not start the call. Dial $kOpsPhoneDisplay.'),
                  ),
                  const SizedBox(height: 10),
                  _ContactTile(
                    icon: Icons.chat_outlined,
                    title: 'WhatsApp',
                    subtitle: kOpsPhoneDisplay,
                    surface: surface,
                    border: border,
                    text: text,
                    sub: sub,
                    accent: accent,
                    onTap: _whatsApp,
                  ),
                  const SizedBox(height: 24),

                  // ---- FAQ ----
                  _SectionLabel('Frequently asked', sub),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < kDriverFaq.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, thickness: 1, color: border, indent: 16, endIndent: 16),
                          _FaqTile(item: kDriverFaq[i], text: text, sub: sub, accent: accent),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Still need help ----
                  _SectionLabel('Still need help?', sub),
                  const SizedBox(height: 10),
                  _PrimaryButton(
                    icon: Icons.support_agent_rounded,
                    label: 'Report a problem',
                    accent: accent,
                    isDark: isDark,
                    onTap: () => _emailSupport(subject: 'Driver app — report a problem'),
                  ),
                  const SizedBox(height: 22),

                  // ---- Diagnostics ----
                  _DiagnosticsFooter(
                    driverId: widget.driverId,
                    appVersion: widget.appVersion,
                    sub: sub,
                    border: border,
                    onCopyId: widget.driverId.isEmpty ? null : _copyDriverId,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Campus emergency card
// =============================================================================
class _EmergencyCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCallCampus;
  final VoidCallback onCallNational;
  const _EmergencyCard({
    required this.isDark,
    required this.onCallCampus,
    required this.onCallNational,
  });

  @override
  Widget build(BuildContext context) {
    const red = AppColors.red;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final sub = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: red.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: red.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: red),
              SizedBox(width: 8),
              Text(
                'CAMPUS EMERGENCY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'For any fire, medical, or security emergency on campus, call UDST '
            'Campus Security first.',
            style: TextStyle(fontSize: 13, height: 1.45, color: text),
          ),
          const SizedBox(height: 14),
          // Primary call button
          GestureDetector(
            onTap: onCallCampus,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.call_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Call Campus Security · $kCampusSecurityDisplay',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Expandable procedures
          ...kEmergencyProcedures.map((p) => _ProcedureExpansion(
                procedure: p,
                isDark: isDark,
                text: text,
                sub: sub,
              )),
          const SizedBox(height: 8),
          // National emergency secondary
          InkWell(
            onTap: onCallNational,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.local_phone_outlined, size: 15, color: sub),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Life-threatening emergency off campus? Call $kNationalEmergency '
                      '(Qatar national emergency).',
                      style: TextStyle(fontSize: 12, height: 1.4, color: sub),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Then report the incident to Uni Eats operations (within 2 hours).',
            style: TextStyle(fontSize: 12, height: 1.4, color: sub),
          ),
        ],
      ),
    );
  }
}

class _ProcedureExpansion extends StatelessWidget {
  final EmergencyProcedure procedure;
  final bool isDark;
  final Color text;
  final Color sub;
  const _ProcedureExpansion({
    required this.procedure,
    required this.isDark,
    required this.text,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Strip the default ExpansionTile dividers for a cleaner look.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 28, bottom: 10),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: sub,
        collapsedIconColor: sub,
        leading: Icon(procedure.icon, size: 19, color: AppColors.red),
        title: Text(
          procedure.title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text),
        ),
        children: [
          for (final step in procedure.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 9),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(
                    child: Text(step, style: TextStyle(fontSize: 13, height: 1.45, color: sub)),
                  ),
                ],
              ),
            ),
          if (procedure.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                procedure.note!,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                  color: sub,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared pieces
// =============================================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color surface;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;
  final VoidCallback onTap;
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.surface,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: sub)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: sub),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final FaqItem item;
  final Color text;
  final Color sub;
  final Color accent;
  const _FaqTile({required this.item, required this.text, required this.sub, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: accent,
        collapsedIconColor: sub,
        title: Text(
          item.question,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.3, color: text),
        ),
        children: [
          Text(item.answer, style: TextStyle(fontSize: 13, height: 1.55, color: sub)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? AppColors.darkBg : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsFooter extends StatelessWidget {
  final String driverId;
  final String appVersion;
  final Color sub;
  final Color border;
  final VoidCallback? onCopyId;
  const _DiagnosticsFooter({
    required this.driverId,
    required this.appVersion,
    required this.sub,
    required this.border,
    required this.onCopyId,
  });

  @override
  Widget build(BuildContext context) {
    final shortId = driverId.isEmpty
        ? '—'
        : (driverId.length > 10 ? '${driverId.substring(0, 10)}…' : driverId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: onCopyId,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Driver ID: $shortId', style: TextStyle(fontSize: 11.5, color: sub)),
                if (onCopyId != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.copy_rounded, size: 13, color: sub),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          appVersion.isEmpty || appVersion == '—'
              ? 'Uni Eats Driver'
              : 'Uni Eats Driver · v$appVersion',
          style: TextStyle(fontSize: 11.5, color: sub),
        ),
      ],
    );
  }
}
