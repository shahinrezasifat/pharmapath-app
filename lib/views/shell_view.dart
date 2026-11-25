import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ai_doctor_module/ai_doctor.dart';

import '../app/theme.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/search_controller.dart';
import '../core/navigation_mode.dart';
import '../widgets/glass.dart';
import 'favorites_view.dart';
import 'home_view.dart';
import 'learning_view.dart';
import 'search_view.dart';
import 'settings_view.dart';

enum _NavIconType { medicine, learn, patient, favorites, settings }

class ShellView extends StatefulWidget {
  const ShellView({super.key, this.pages});

  final List<Widget>? pages;

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  final NavigationController _nav = Get.find<NavigationController>();

  late final List<Widget> _pages =
      widget.pages ??
      const [
        HomeView(),
        SearchView(),
        LearningView(),
        const AiDoctorHomePage(isTab: true),
        FavoritesView(),
        SettingsView(),
      ];

  static const _destinations = <({_NavIconType type, String label})>[
    (type: _NavIconType.medicine, label: 'ঔষধ'),
    (type: _NavIconType.learn, label: 'শেখা'),
    (type: _NavIconType.patient, label: 'রোগী'),
    (type: _NavIconType.favorites, label: 'প্রিয়'),
    (type: _NavIconType.settings, label: 'সেটিংস'),
  ];

  static const _pageTitles = [
    'ওষুধ',
    'খুঁজুন',
    'শেখা',
    'রোগী',
    'প্রিয়',
    'সেটিংস',
  ];

  static const _pageIndexes = [0, 2, 3, 4, 5];

  void _onSelect(int destinationIndex) {
    final pageIndex = _pageIndexes[destinationIndex.clamp(0, _pageIndexes.length - 1)];
    _nav.goTo(pageIndex);
    _onRefresh(pageIndex);
  }

  /// Refresh means "reload this page", never "jump to another tab". The old
  /// implementation sent the search page back to Home because the refresh
  /// button reused the selected destination index.
  void _onRefresh(int pageIndex) {
    switch (pageIndex) {
      case 0:
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().load();
        }
        break;
      case 1:
        if (Get.isRegistered<MedicineSearchController>()) {
          final search = Get.find<MedicineSearchController>();
          search.refreshHistory();
          if (search.query.value.trim().isNotEmpty) {
            search.search(record: false);
          }
        }
        break;
      case 4:
        if (Get.isRegistered<FavoritesController>()) {
          Get.find<FavoritesController>().load();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeyboardOpen =
        View.of(context).viewInsets.bottom > 0 ||
        MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomInset = GestureNavigation.gestureBarHeight(context);

    return Obx(() {
      final index = _nav.index.value;
      final selectedDestination = switch (index) {
        2 => 1,
        3 => 2,
        4 => 3,
        5 => 4,
        _ => 0,
      };

      // Design token colors from the HTML/CSS specification:
      // Light:
      // --bg:#f2f5fb; --text:#0e1a33; --muted:#667694; --line:#e3e9f5;
      // --brand:#2f6df6; --brand2:#6aa8ff; --nav:rgba(255,255,255,.85);
      // Dark:
      // --bg:#070d1c; --text:#eaf0ff; --muted:#8d9bb8; --line:#1f2d4a; --nav:rgba(17,26,48,.88);
      final navBg = isDark
          ? const Color(0xE0111A30) // rgba(17,26,48,.88)
          : const Color(0xD9FFFFFF); // rgba(255,255,255,.85)
      final navLine = isDark
          ? const Color(0xFF1F2D4A) // #1f2d4a
          : const Color(0xFFE3E9F5); // #e3e9f5
      final mutedColor = isDark
          ? const Color(0xFF8D9BB8) // #8d9bb8
          : const Color(0xFF667694); // #667694

      // Clamp once: the header, the page stack and the highlighted tab must
      // never disagree about which page is actually visible.
      final safeIndex = index.clamp(0, _pages.length - 1);
      return Scaffold(
        backgroundColor: scheme.surface,
        // The bar is an overlay, not a docked band: the page content extends
        // underneath it so the glass blur has something real to sample and no
        // empty strip is reserved at the bottom of the screen.
        extendBody: true,
        body: Stack(
          children: [
            AppBackground(
              child: Column(
                children: [
                  _SectionHeader(
                    index: safeIndex,
                    title: _pageTitles[safeIndex],
                    onSearch: () => _nav.goTo(1),
                    onRefresh: () => _onRefresh(safeIndex),
                  ),
                  Expanded(
                    child: IndexedStack(index: safeIndex, children: _pages),
                  ),
                ],
              ),
            ),
            if (!isKeyboardOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 14 + bottomInset,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    // Shadow lives OUTSIDE the clip, otherwise it is cut away
                    // and the pill reads as flat/pinned instead of floating.
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x402557C5), // rgba(37,87,197,.25)
                            blurRadius: 40,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: navBg,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: navLine, width: 1),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        for (
                                          var i = 0;
                                          i < _destinations.length;
                                          i++
                                        )
                                          _NavigationDestination(
                                            type: _destinations[i].type,
                                            label: _destinations[i].label,
                                            selected: selectedDestination == i,
                                            mutedColor: mutedColor,
                                            onTap: () => _onSelect(i),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.index,
    required this.title,
    required this.onSearch,
    required this.onRefresh,
  });

  final int index;
  final String title;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isHome = index == 0;
    final showSearch = index == 0 || index == 1;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/LOGO.jpg', fit: BoxFit.cover),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isHome ? 'ফার্মাপাথ' : title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    isHome
                        ? 'ওষুধ জানুন। ভালো বুঝুন।'
                        : 'PharmaPath · অফলাইন-ফার্স্ট',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (showSearch)
              IconButton.filledTonal(
                tooltip: 'ওষুধ খুঁজুন',
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
              ),
            if (index == 1 || index == 4)
              IconButton(
                tooltip: 'রিফ্রেশ',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavigationDestination extends StatefulWidget {
  const _NavigationDestination({
    required this.type,
    required this.label,
    required this.selected,
    required this.mutedColor,
    required this.onTap,
  });

  final _NavIconType type;
  final String label;
  final bool selected;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  State<_NavigationDestination> createState() => _NavigationDestinationState();
}

class _NavigationDestinationState extends State<_NavigationDestination> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) {
    setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _pressed = false);
  }

  void _onTapCancel() {
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: 46,
              padding: EdgeInsets.symmetric(
                horizontal: widget.selected ? 12 : 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: widget.selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2F6DF6), // --brand: #2f6df6
                          Color(0xFF6AA8FF), // --brand2: #6aa8ff
                        ],
                      )
                    : null,
                border: widget.selected
                    ? Border.all(
                        color: const Color(
                          0x59FFFFFF,
                        ), // inset 0 1px 0 rgba(255,255,255,.35)
                        width: 1.0,
                      )
                    : null,
                boxShadow: widget.selected
                    ? const [
                        BoxShadow(
                          color: Color(0x732F6DF6), // rgba(47,109,246,.45)
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _NavSvgIcon(
                    type: widget.type,
                    color: widget.selected ? Colors.white : widget.mutedColor,
                    size: 24,
                  ),
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      reverseDuration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      child: widget.selected
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                Text(
                                  widget.label,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSvgIcon extends StatelessWidget {
  const _NavSvgIcon({
    required this.type,
    required this.color,
    this.size = 24.0,
  });

  final _NavIconType type;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NavSvgPainter(type: type, color: color),
      ),
    );
  }
}

class _NavSvgPainter extends CustomPainter {
  _NavSvgPainter({required this.type, required this.color});

  final _NavIconType type;
  final Color color;

  static final Path _pillOutline = _parseSvgPath(
    'm10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7z',
  );
  static final Path _pillDivider = _parseSvgPath('m8.5 8.5 7 7');
  static final Path _bookLeft = _parseSvgPath(
    'M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z',
  );
  static final Path _bookRight = _parseSvgPath(
    'M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z',
  );
  static final Path _userBody = _parseSvgPath('M4 21a8 8 0 0 1 16 0');
  static final Path _bookmark = _parseSvgPath(
    'm19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z',
  );
  static final Path _settingsGear = _parseSvgPath(
    'M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z',
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width != 24.0 || size.height != 24.0) {
      canvas.scale(size.width / 24.0, size.height / 24.0);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case _NavIconType.medicine:
        canvas.drawPath(_pillOutline, paint);
        canvas.drawPath(_pillDivider, paint);
        break;
      case _NavIconType.learn:
        canvas.drawPath(_bookLeft, paint);
        canvas.drawPath(_bookRight, paint);
        break;
      case _NavIconType.patient:
        canvas.drawCircle(const Offset(12, 8), 4, paint);
        canvas.drawPath(_userBody, paint);
        break;
      case _NavIconType.favorites:
        canvas.drawPath(_bookmark, paint);
        break;
      case _NavIconType.settings:
        canvas.drawPath(_settingsGear, paint);
        canvas.drawCircle(const Offset(12, 12), 3, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _NavSvgPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}

Path _parseSvgPath(String d) {
  final path = Path();
  final reg = RegExp(r'([a-zA-Z])|([-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?)');
  final tokens = <String>[];
  for (final m in reg.allMatches(d)) {
    tokens.add(m.group(0)!);
  }

  int i = 0;
  String currentCmd = '';
  double curX = 0;
  double curY = 0;
  double startX = 0;
  double startY = 0;

  bool isCmd(String t) => t.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(t);

  while (i < tokens.length) {
    if (isCmd(tokens[i])) {
      currentCmd = tokens[i];
      i++;
    }

    switch (currentCmd) {
      case 'M':
        final x = double.parse(tokens[i++]);
        final y = double.parse(tokens[i++]);
        curX = x;
        curY = y;
        startX = x;
        startY = y;
        path.moveTo(x, y);
        currentCmd = 'L';
        break;

      case 'm':
        final x = curX + double.parse(tokens[i++]);
        final y = curY + double.parse(tokens[i++]);
        curX = x;
        curY = y;
        startX = x;
        startY = y;
        path.moveTo(x, y);
        currentCmd = 'l';
        break;

      case 'L':
        final x = double.parse(tokens[i++]);
        final y = double.parse(tokens[i++]);
        curX = x;
        curY = y;
        path.lineTo(x, y);
        break;

      case 'l':
        final x = curX + double.parse(tokens[i++]);
        final y = curY + double.parse(tokens[i++]);
        curX = x;
        curY = y;
        path.lineTo(x, y);
        break;

      case 'H':
        final x = double.parse(tokens[i++]);
        curX = x;
        path.lineTo(curX, curY);
        break;

      case 'h':
        final x = curX + double.parse(tokens[i++]);
        curX = x;
        path.lineTo(curX, curY);
        break;

      case 'V':
        final y = double.parse(tokens[i++]);
        curY = y;
        path.lineTo(curX, curY);
        break;

      case 'v':
        final y = curY + double.parse(tokens[i++]);
        curY = y;
        path.lineTo(curX, curY);
        break;

      case 'A':
        final rx = double.parse(tokens[i++]);
        final ry = double.parse(tokens[i++]);
        final rot = double.parse(tokens[i++]) * (math.pi / 180.0);
        final large = double.parse(tokens[i++]).toInt() == 1;
        final sweep = double.parse(tokens[i++]).toInt() == 1;
        final x = double.parse(tokens[i++]);
        final y = double.parse(tokens[i++]);
        curX = x;
        curY = y;
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
        break;

      case 'a':
        final rx = double.parse(tokens[i++]);
        final ry = double.parse(tokens[i++]);
        final rot = double.parse(tokens[i++]) * (math.pi / 180.0);
        final large = double.parse(tokens[i++]).toInt() == 1;
        final sweep = double.parse(tokens[i++]).toInt() == 1;
        final x = curX + double.parse(tokens[i++]);
        final y = curY + double.parse(tokens[i++]);
        curX = x;
        curY = y;
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
        break;

      case 'Z':
      case 'z':
        path.close();
        curX = startX;
        curY = startY;
        break;

      default:
        i++;
        break;
    }
  }

  return path;
}
