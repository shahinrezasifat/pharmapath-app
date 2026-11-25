import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/app_config.dart';

/// Redesigned header following Material Design 3 principles
/// Features: Dynamic color scheme, glassmorphism, improved visual hierarchy
class RedesignedHeader extends StatelessWidget {
  const RedesignedHeader({
    super.key,
    required this.onSettings,
    required this.onData,
    required this.onSearch,
    required this.medicineCount,
    this.showStats = true,
  });

  final VoidCallback onSettings;
  final VoidCallback onData;
  final VoidCallback onSearch;
  final int medicineCount;
  final bool showStats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Main Hero Section with Glassmorphism
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [scheme.primaryContainer, scheme.secondaryContainer]
                  : [
                      scheme.primary.withAlpha(20),
                      scheme.secondary.withAlpha(20),
                    ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: BackdropFilter(
              filter: AppTheme.blurFilter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 16,
                  20,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Bar Row with Logo and Actions
                    Row(
                      children: [
                        // App Logo with Glass Effect
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withAlpha(20),
                            border: Border.all(
                              color: Colors.white.withAlpha(40),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withAlpha(30),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/LOGO.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // App Name and Tagline
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConfig.appName,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.onSurface,
                                      letterSpacing: -0.5,
                                    ),
                              ),
                              Text(
                                AppConfig.tagline,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        // Action Buttons
                        Row(
                          children: [
                            _buildActionButton(
                              icon: Icons.storage_outlined,
                              tooltip: 'ডেটা',
                              onPressed: onData,
                              scheme: scheme,
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.tune_rounded,
                              tooltip: 'সেটিংস',
                              onPressed: onSettings,
                              scheme: scheme,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Welcome Message
                    Text(
                      'স্বাগতম, ফার্মাসিস্ট!',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'আপনার জন্য আজকের সুপারিশ ও আপডেট',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    // Stats Overview
                    if (showStats)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow.withAlpha(150),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: scheme.outlineVariant.withAlpha(80),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildStatItem(
                              value: '$medicineCount',
                              label: 'ঔষধ',
                              icon: Icons.medical_services_outlined,
                              color: scheme.primary,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              color: scheme.outlineVariant.withAlpha(80),
                            ),
                            _buildStatItem(
                              value: '১০০%',
                              label: 'অফলাইন',
                              icon: Icons.cloud_off_outlined,
                              color: scheme.secondary,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              color: scheme.outlineVariant.withAlpha(80),
                            ),
                            _buildStatItem(
                              value: '২৪/৭',
                              label: 'সাপোর্ট',
                              icon: Icons.support_agent_outlined,
                              color: scheme.tertiary,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Search Bar Section (positioned to overlap)
        Transform.translate(
          offset: const Offset(0, -24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSearchBar(context, scheme),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ColorScheme scheme,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHigh.withAlpha(180),
        border: Border.all(
          color: scheme.outlineVariant.withAlpha(80),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: scheme.onSurface,
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 20,
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ColorScheme scheme) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: scheme.surface,
      child: InkWell(
        onTap: onSearch,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: scheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ঔষধ, রোগ, বা কোম্পানি খুঁজুন',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'বাংলা বা ইংরেজি যেকোনো ভাষায় লিখুন',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern quick action grid with improved visual design
class RedesignedFeatureGrid extends StatelessWidget {
  const RedesignedFeatureGrid({
    super.key,
    required this.tiles,
    this.columns = 4,
  });

  final List<RedesignedGridTileData> tiles;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) {
        final tile = tiles[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: tile.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color:
                    tile.backgroundColor?.withAlpha(isDark ? 40 : 15) ??
                    scheme.surfaceContainerLow,
                border: Border.all(
                  color:
                      tile.backgroundColor?.withAlpha(isDark ? 80 : 30) ??
                      scheme.outlineVariant.withAlpha(60),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withAlpha(isDark ? 30 : 10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          tile.backgroundColor?.withAlpha(isDark ? 60 : 25) ??
                          scheme.primaryContainer,
                    ),
                    child: Icon(
                      tile.icon,
                      size: 24,
                      color: tile.iconColor ?? scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tile.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tile.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      tile.subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class RedesignedGridTileData {
  const RedesignedGridTileData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.backgroundColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;
}

/// Modern promo banner with gradient and animation support
class RedesignedPromoBanner extends StatelessWidget {
  const RedesignedPromoBanner({
    super.key,
    required this.onTap,
    this.title = 'AI সহায়ক',
    this.subtitle = 'যেকোনো রোগ বা ঔষধ লিখুন — ডাক্তারের মতো গাইড',
    this.icon = Icons.auto_awesome_rounded,
    this.gradient,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final defaultGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [scheme.primary, scheme.secondary],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: gradient ?? defaultGradient,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withAlpha(80),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(30),
                    border: Border.all(
                      color: Colors.white.withAlpha(50),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withAlpha(220),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern section title with improved typography
class RedesignedSectionTitle extends StatelessWidget {
  const RedesignedSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(2, 24, 2, 12),
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
              ),
              child: Text(
                action!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
