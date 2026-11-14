import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/layout/book_layout.dart';
import '../core/localization/app_localizations.dart';
import '../features/home/presentation/mosque_backdrop.dart';

class AdaptiveBookShell extends StatefulWidget {
  final StatefulNavigationShell shell;
  final String location;
  const AdaptiveBookShell({
    super.key,
    required this.shell,
    required this.location,
  });

  @override
  State<AdaptiveBookShell> createState() => _AdaptiveBookShellState();
}

class _AdaptiveBookShellState extends State<AdaptiveBookShell> {
  bool? _wasExpanded;
  bool _expanded = false;

  static const icons = [
    Icons.home_outlined,
    Icons.menu_book_outlined,
    Icons.mosque_outlined,
    Icons.calendar_month_outlined,
    Icons.settings_outlined,
  ];
  static const labels = [
    'nav.home',
    'nav.quran',
    'nav.worship',
    'nav.calendar',
    'nav.settings',
  ];

  void _select(int index) => widget.shell.goBranch(index);

  void _resize(bool expanded) {
    _expanded = expanded;
    final previous = _wasExpanded;
    _wasExpanded = expanded;
    // Do not override a deep link on launch. An actual window expansion
    // opens the reader; closing returns home without resetting branch stacks.
    if ((previous != null && previous != expanded) ||
        (previous == null && expanded && widget.location == '/')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _expanded == expanded) _select(expanded ? 1 : 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final expanded = isBookDisplay(constraints.biggest);
      _resize(expanded);
      final onHome = widget.shell.currentIndex == 0;
      final l10n = context.l10n;
      return BookLayoutScope(
        expanded: expanded,
        child: MosqueBackdrop(
          // Worship keeps the same living scene; its paper pages supply contrast.
          scrim: onHome || (expanded && widget.shell.currentIndex == 2)
              ? BackdropScrim.light
              : BackdropScrim.heavy,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: !expanded,
            // Keep this subtree in the same slot across resizes. Navigator stacks,
            // PageStorage and the single MosqueScene must not be recreated.
            body: Row(
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, pane) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(size: pane.biggest),
                      child: widget.shell,
                    ),
                  ),
                ),
                if (expanded)
                  SafeArea(
                    left: false,
                    child: SizedBox(
                      key: const ValueKey('book-right-navigation'),
                      width: 76,
                      child: Material(
                        color: const Color(0xEB0A2425),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < labels.length;
                                index++
                              )
                                Semantics(
                                  selected: widget.shell.currentIndex == index,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          widget.shell.currentIndex == index
                                          ? const Color(0xFFFFD88A)
                                          : const Color(0xFFDCE7E4),
                                      minimumSize: const Size(72, 64),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 10,
                                      ),
                                    ),
                                    onPressed: () => _select(index),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icons[index], size: 21),
                                        const SizedBox(height: 4),
                                        Text(
                                          l10n.text(labels[index]),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11),
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
                  ),
              ],
            ),
            bottomNavigationBar: expanded
                ? null
                : NavigationBarTheme(
                    data: onHome
                        ? NavigationBarThemeData(
                            backgroundColor: const Color(0xF20A2425),
                            indicatorColor: const Color(0x40FFD88A),
                            iconTheme: WidgetStateProperty.resolveWith(
                              (states) => IconThemeData(
                                color: states.contains(WidgetState.selected)
                                    ? const Color(0xFFFFD88A)
                                    : const Color(0xFFDCE7E4),
                              ),
                            ),
                            labelTextStyle: WidgetStateProperty.resolveWith(
                              (states) => TextStyle(
                                color: states.contains(WidgetState.selected)
                                    ? const Color(0xFFFFD88A)
                                    : const Color(0xFFDCE7E4),
                                fontWeight:
                                    states.contains(WidgetState.selected)
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : const NavigationBarThemeData(),
                    child: NavigationBar(
                      selectedIndex: widget.shell.currentIndex,
                      onDestinationSelected: _select,
                      destinations: [
                        for (var i = 0; i < labels.length; i++)
                          NavigationDestination(
                            icon: Icon(icons[i]),
                            label: l10n.text(labels[i]),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    },
  );
}
