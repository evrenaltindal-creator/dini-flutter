import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import 'book_layout.dart';

/// Each chunk retains its offset in the original, unmodified text. Reflowing
/// a book changes page boundaries, never font size or the reading anchor.
List<({int start, String text})> paginateBookText({
  required String text,
  required double width,
  required double height,
  required TextStyle style,
  required TextDirection direction,
  required TextScaler scaler,
  required Locale locale,
}) {
  final boundaries = <int>[0];
  for (final character in text.characters) {
    boundaries.add(boundaries.last + character.length);
  }
  final pages = <({int start, String text})>[];
  var start = 0;
  final painter = TextPainter(
    textDirection: direction,
    textScaler: scaler,
    locale: locale,
  );
  try {
    while (start < boundaries.length - 1) {
      var low = start + 1, high = boundaries.length - 1, best = start;
      while (low <= high) {
        final mid = (low + high) ~/ 2;
        painter.text = TextSpan(
          text: text.substring(boundaries[start], boundaries[mid]),
          style: style,
        );
        painter.layout(maxWidth: width);
        if (painter.height <= height) {
          best = mid;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }
      // Even at an extreme accessibility scale a grapheme remains intact.
      // The paper can scroll in that case; text is never clipped or shrunk.
      if (best == start) best++;
      if (best < boundaries.length - 1) {
        var word = best;
        while (word > start &&
            !RegExp(r'\s').hasMatch(
              text.substring(boundaries[word - 1], boundaries[word]),
            )) {
          word--;
        }
        if (word > start) best = word;
      }
      pages.add((
        start: boundaries[start],
        text: text.substring(boundaries[start], boundaries[best]),
      ));
      start = best;
    }
  } finally {
    painter.dispose();
  }
  return pages.isEmpty ? [(start: 0, text: '')] : pages;
}

class BookTextReader extends StatefulWidget {
  final String text;
  final String storageId;
  final TextDirection? readingDirection;
  final bool arabic;
  const BookTextReader({
    super.key,
    required this.text,
    required this.storageId,
    this.readingDirection,
    this.arabic = false,
  });
  @override
  State<BookTextReader> createState() => _BookTextReaderState();
}

class _BookTextReaderState extends State<BookTextReader>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  PageController? controller;
  Object? layoutKey;
  List<({int start, String text})> pages = [];
  int anchor = 0, group = 0;
  bool restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!restored) {
      anchor =
          PageStorage.maybeOf(context)
                  ?.readState(context, identifier: widget.storageId)
              as int? ??
          0;
      restored = true;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final direction = widget.readingDirection ?? Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.localeOf(context);
    final style = TextStyle(
      inherit: false,
      color: bookInk,
      fontSize: widget.arabic ? 23 : 17,
      height: widget.arabic ? 1.9 : 1.65,
      fontFamily: widget.arabic ? 'AmiriQuran' : null,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final two = bookDisplayOf(context) && constraints.maxWidth >= 560;
        final count = two ? 2 : 1;
        final width = ((constraints.maxWidth - (two ? 20 : 0)) / count - 32)
            .clamp(1.0, double.infinity);
        final height = (constraints.maxHeight - 88).clamp(
          40.0,
          double.infinity,
        );
        final signature = (
          widget.text,
          width,
          height,
          scaler,
          locale,
          direction,
          widget.arabic,
        );
        if (signature != layoutKey) {
          layoutKey = signature;
          pages = paginateBookText(
            text: widget.text,
            width: width,
            height: height,
            style: style,
            direction: direction,
            scaler: scaler,
            locale: locale,
          );
          var page = pages.lastIndexWhere((p) => p.start <= anchor);
          if (page < 0) page = 0;
          group = page ~/ count;
          final previous = controller;
          controller = PageController(initialPage: group, keepPage: false);
          if (previous != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => previous.dispose(),
            );
          }
        }
        final groups = (pages.length + count - 1) ~/ count;
        Widget paper(int index) => BookPaper(
          child: index >= pages.length
              ? const SizedBox.expand()
              : SingleChildScrollView(
                  child: Text(
                    pages[index].text,
                    textDirection: direction,
                    locale: locale,
                    style: style,
                  ),
                ),
        );
        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: ValueKey(signature),
                controller: controller,
                reverse: direction == TextDirection.rtl,
                itemCount: groups,
                onPageChanged: (index) {
                  anchor = pages[index * count].start;
                  PageStorage.maybeOf(
                    context,
                  )?.writeState(context, anchor, identifier: widget.storageId);
                  setState(() => group = index);
                },
                itemBuilder: (context, index) => two
                    ? BookSpread(
                        readingDirection: direction,
                        first: paper(index * 2),
                        second: paper(index * 2 + 1),
                      )
                    : paper(index),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: context.l10n.text('book.previous'),
                  onPressed: group > 0
                      ? () => controller!.previousPage(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        )
                      : null,
                  icon: Icon(
                    direction == TextDirection.rtl
                        ? Icons.chevron_right
                        : Icons.chevron_left,
                  ),
                ),
                Flexible(
                  child: Text(
                    context.l10n.text('book.position', {
                      'current': group + 1,
                      'total': groups,
                    }),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.text('book.next'),
                  onPressed: group + 1 < groups
                      ? () => controller!.nextPage(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        )
                      : null,
                  icon: Icon(
                    direction == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
