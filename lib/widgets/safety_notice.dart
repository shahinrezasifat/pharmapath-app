import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/app_config.dart';

/// Medical disclaimer notice shown prominently on the home page.
///
/// The [dense] variant is used wherever space is tight (e.g. detail sheets).
/// The default variant is the full-width expandable card on the home page.
class SafetyNotice extends StatelessWidget {
  const SafetyNotice({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (dense) return _buildDense(context);
    return const _MedicalDisclaimerCard();
  }

  Widget _buildDense(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            size: 16,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppConfig.safetyNotice,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onTertiaryContainer, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prominent, full-width medical disclaimer card for the home page.
/// Uses a warm amber/orange warning tone to draw attention without alarm.
/// Tapping expands to reveal the full disclaimer text.
class _MedicalDisclaimerCard extends StatefulWidget {
  const _MedicalDisclaimerCard();

  @override
  State<_MedicalDisclaimerCard> createState() => _MedicalDisclaimerCardState();
}

class _MedicalDisclaimerCardState extends State<_MedicalDisclaimerCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primaryContainer.withValues(alpha: 0.45);
    final border = scheme.primary.withValues(alpha: 0.35);
    final iconColor = scheme.primary;
    final titleColor = scheme.onPrimaryContainer;
    final bodyColor = scheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ─────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(
                        Icons.health_and_safety_rounded,
                        size: 18,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'চিকিৎসা সংক্রান্ত সতর্কতা',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: titleColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'বিস্তারিত দেখতে ট্যাপ করুন',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: bodyColor.withValues(alpha: 0.65),
                                ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 260),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: iconColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                // ── Expandable body ─────────────────────────────────────────
                FadeTransition(
                  opacity: _fade,
                  child: SizeTransition(
                    sizeFactor: _fade,
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 11),
                        Divider(height: 1, color: border),
                        const SizedBox(height: 11),
                        Text(
                          AppConfig.safetyNotice,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: bodyColor, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
