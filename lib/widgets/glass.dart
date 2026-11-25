import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Page background shared by every screen. A single flat surface colour —
/// no gradient wash, no blurred orbs, no backdrop filters.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.safe = false});

  final Widget child;
  final bool safe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = safe ? SafeArea(child: child) : child;
    return ColoredBox(color: scheme.surface, child: content);
  }
}

/// Content card. A solid surface with a hairline outline and a gentle, modern
/// shadow — the calm elevated look shared across the whole app.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color,
    this.gradient,
    this.borderRadius = AppTheme.radius,
    this.blur = 0,
    this.borderColor,
    this.showShadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double borderRadius;
  final double blur;
  final Color? borderColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);
    final background = color ?? scheme.surfaceContainerLow;
    final border = borderColor ?? scheme.outlineVariant;
    final body = Padding(padding: padding, child: child);
    final dark = AppTheme.isDark(context);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? background : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: border),
        boxShadow: gradient == null
            ? [
                BoxShadow(
                  color: Color.alphaBlend(
                    scheme.shadow.withValues(alpha: dark ? 0.28 : 0.06),
                    Colors.transparent,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                  spreadRadius: -6,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: radius, child: body),
      ),
    );
  }
}

/// Flat status label used for small metadata.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: tint),
            SizedBox(width: compact ? 4 : 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: tint, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }
}

/// Soft tinted icon. No gradient, no shadow, no heavy container.
class GradientIcon extends StatelessWidget {
  const GradientIcon({
    super.key,
    required this.icon,
    this.size = 44,
    this.radius = 12,
    this.colors,
  });

  final IconData icon;
  final double size;
  final double radius;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = colors?.first ?? scheme.primary;
    final dark = AppTheme.isDark(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: dark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tint.withValues(alpha: dark ? 0.34 : 0.2)),
      ),
      child: Icon(icon, color: tint, size: size * 0.5),
    );
  }
}

/// Section heading with an optional text action.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(4, 22, 4, 10),
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action!),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 11),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact statistic used in summary panels.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.onLight = false,
  });

  final String value;
  final String label;
  final IconData? icon;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valueColor = onLight ? Colors.white : scheme.onSurface;
    final labelColor = onLight
        ? Colors.white.withValues(alpha: 0.88)
        : scheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: labelColor),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: valueColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: labelColor),
        ),
      ],
    );
  }
}

/// Standard settings row. The leading icon is plain — no tinted tile — so
/// long settings pages stay visually quiet.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = danger ? scheme.error : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: danger ? scheme.error : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
          ],
        ),
      ),
    );
  }
}

/// Group of [SettingsTile]s separated by a hairline, inside a flat card.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            indent: 46,
            endIndent: 14,
            color: scheme.outlineVariant,
          ),
        );
      }
      rows.add(children[i]);
    }
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: rows),
    );
  }
}
