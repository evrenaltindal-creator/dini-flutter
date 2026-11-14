import 'package:flutter/material.dart';

/// Layout follows the available window, never the device's model name.
/// A short, landscape phone still uses the original compact experience.
bool isBookDisplay(Size size) => size.width >= 700 && size.height >= 500;

bool bookDisplayOf(BuildContext context) =>
    BookLayoutScope.maybeOf(context) ??
    isBookDisplay(MediaQuery.sizeOf(context));

class BookLayoutScope extends InheritedWidget {
  final bool expanded;
  const BookLayoutScope({
    super.key,
    required this.expanded,
    required super.child,
  });
  static bool? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BookLayoutScope>()?.expanded;
  @override
  bool updateShouldNotify(BookLayoutScope oldWidget) =>
      expanded != oldWidget.expanded;
}

const bookPaper = Color(0xFFF9F5E9);
const bookInk = Color(0xFF263C30);

/// Two physical pages. Reading order is independent of the app locale and
/// the right-hand navigation rail, as explicitly requested by the owner.
class BookSpread extends StatelessWidget {
  final Widget first, second;
  final TextDirection readingDirection;
  final double gap;

  const BookSpread({
    super.key,
    required this.first,
    required this.second,
    this.readingDirection = TextDirection.ltr,
    this.gap = 20,
  });

  @override
  Widget build(BuildContext context) {
    Widget pane(Widget child) => LayoutBuilder(
      builder: (context, constraints) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: constraints.biggest),
        child: child,
      ),
    );
    final children = [
      Expanded(child: pane(first)),
      SizedBox(width: gap),
      Expanded(child: pane(second)),
    ];
    return Row(
      textDirection: readingDirection,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class BookPaper extends StatelessWidget {
  final Widget child;
  const BookPaper({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: bookPaper,
      borderRadius: BorderRadius.circular(8),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: bookInk),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}
