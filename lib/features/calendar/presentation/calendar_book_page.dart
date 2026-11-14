import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/book_layout.dart';
import '../../prayer_times/domain/timezone_service.dart';
import '../../prayer_times/presentation/providers.dart';
import 'calendar_page.dart';
import 'daily_leaf_page.dart';

class CalendarBookPage extends ConsumerStatefulWidget {
  final bool showMonthWhenCompact;
  const CalendarBookPage({super.key, this.showMonthWhenCompact = false});
  @override
  ConsumerState<CalendarBookPage> createState() => _CalendarBookPageState();
}

class _CalendarBookPageState extends ConsumerState<CalendarBookPage> {
  late DateTime selected;
  @override
  void initState() {
    super.initState();
    final settings = ref.read(effectivePrayerSettingsProvider);
    final now = TimezoneService.inLocation(
      settings.location.timezoneId ?? 'Europe/Istanbul',
      ref.read(clockProvider)(),
    );
    selected = DateUtils.dateOnly(now);
  }

  void _select(DateTime date) {
    // A programmatic leaf jump echoes the already selected date. Avoid a
    // rebuild loop (and notifying the parent during its child's layout).
    if (!DateUtils.isSameDay(date, selected)) setState(() => selected = date);
  }

  @override
  Widget build(BuildContext context) {
    final expanded = bookDisplayOf(context);
    // Stable slots keep the leaf's pager and the month selection alive.
    final leaf = DailyLeafPage(
      key: const ValueKey('book-daily-leaf'),
      embedded: true,
      showModeSwitch: !expanded,
      selectedDate: selected,
      onDateChanged: _select,
    );
    final month = CalendarPage(
      key: const ValueKey('book-month'),
      embedded: expanded,
      selectedDate: selected,
      onSelectedDate: _select,
    );
    if (!expanded) return widget.showMonthWhenCompact ? month : leaf;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: BookSpread(first: leaf, second: month),
      ),
    );
  }
}
