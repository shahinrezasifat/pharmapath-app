import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/medicine.dart';
import 'company_logo.dart';
import 'medicine_form_icons.dart';

class MedicineCard extends StatelessWidget {
  const MedicineCard({
    super.key,
    required this.medicine,
    this.onTap,
    this.trailing,
    this.showPrice = true,
  });

  final Medicine medicine;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = MedicineFormIcon.colorOf(medicine.form);
    final generic = medicine.genericName?.trim() ?? '';
    final strength = medicine.strength?.trim() ?? '';
    final identity = [
      if (generic.isNotEmpty) generic,
      if (strength.isNotEmpty) strength,
    ].join(' · ');
    final company = medicine.company?.trim() ?? '';

    return _PressScale(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.isDark(context)
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .6),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: .04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  MedicineFormGlyph(form: medicine.form, size: 48),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        if (identity.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            identity,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _InfoChip(
                              icon: MedicineFormIcon.of(medicine.form),
                              label: medicine.form.label,
                              color: accent,
                            ),
                            if (showPrice)
                              _InfoChip(
                                icon: Icons.sell_outlined,
                                label: medicine.hasPrice
                                    ? medicine.priceLabel
                                    : 'দাম নেই',
                                color: medicine.hasPrice
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                                emphasized: medicine.hasPrice,
                              ),
                          ],
                        ),
                        if (medicine.isExpired ||
                            (medicine.isManual &&
                                (medicine.daysToExpiry ?? 999) <= 60))
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: _ExpiryLabel(medicine: medicine),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CompanyLogo(
                    company: company,
                    size: 40,
                    radius: 11,
                    padding: 2,
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: .8)
            : color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: emphasized ? scheme.onPrimaryContainer : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiryLabel extends StatelessWidget {
  const _ExpiryLabel({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expired = medicine.isExpired;
    final color = expired ? scheme.error : scheme.tertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          expired ? Icons.event_busy_rounded : Icons.access_time_rounded,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          expired ? 'মেয়াদ শেষ' : 'মেয়াদ আসন্ন',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => _pressed = true),
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

class MedicineSquareTile extends StatelessWidget {
  const MedicineSquareTile({super.key, required this.medicine, this.onTap});

  final Medicine medicine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      MedicineCard(medicine: medicine, onTap: onTap);
}
