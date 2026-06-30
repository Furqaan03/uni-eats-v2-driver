import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'policies.dart';

/// Full-screen reader for a single [PolicyDoc]. Linear scroll (policies read
/// top-to-bottom), with a pinned compact header that fades the long title in
/// as the big title scrolls away.
class PolicyViewerScreen extends StatefulWidget {
  final PolicyDoc policy;
  const PolicyViewerScreen({super.key, required this.policy});

  @override
  State<PolicyViewerScreen> createState() => _PolicyViewerScreenState();
}

class _PolicyViewerScreenState extends State<PolicyViewerScreen> {
  final _scroll = ScrollController();
  bool _showCompactTitle = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 64;
      if (show != _showCompactTitle) setState(() => _showCompactTitle = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final sub = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accent = isDark ? AppColors.yellow : AppColors.orange;
    final p = widget.policy;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Compact top bar — back button + title that fades in on scroll.
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
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                children: [
                  // Big title
                  Text(
                    p.title,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Metadata chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(icon: Icons.tag_rounded, label: p.ref, sub: sub, border: border),
                      _MetaChip(
                        icon: Icons.event_available_rounded,
                        label: 'Effective ${p.effectiveDate}',
                        sub: sub,
                        border: border,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Key takeaway highlight card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.12 : 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border(left: BorderSide(color: accent, width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 15, color: accent),
                            const SizedBox(width: 6),
                            Text(
                              'KEY TAKEAWAY',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.takeaway,
                          style: TextStyle(fontSize: 13.5, height: 1.5, color: text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Sections
                  for (final section in p.sections)
                    _SectionView(
                      section: section,
                      text: text,
                      sub: sub,
                      accent: accent,
                    ),
                  const SizedBox(height: 16),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_outlined, size: 18, color: sub),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Official Uni Eats policy document. Questions? '
                            'Contact support@unieats.qa',
                            style: TextStyle(fontSize: 12, height: 1.4, color: sub),
                          ),
                        ),
                      ],
                    ),
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color sub;
  final Color border;
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.sub,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: sub),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sub),
          ),
        ],
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  final PolicySection section;
  final Color text;
  final Color sub;
  final Color accent;
  const _SectionView({
    required this.section,
    required this.text,
    required this.sub,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // Section heading with a leading accent bar.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 18,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Text(
                section.heading,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final block in section.blocks) _BlockView(block: block, text: text, sub: sub, accent: accent),
      ],
    );
  }
}

class _BlockView extends StatelessWidget {
  final PolicyBlock block;
  final Color text;
  final Color sub;
  final Color accent;
  const _BlockView({
    required this.block,
    required this.text,
    required this.sub,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case PolicyBlockType.subhead:
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
        );
      case PolicyBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            block.text,
            style: TextStyle(fontSize: 14, height: 1.6, color: sub),
          ),
        );
      case PolicyBlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 10),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  block.text,
                  style: TextStyle(fontSize: 14, height: 1.5, color: sub),
                ),
              ),
            ],
          ),
        );
    }
  }
}
