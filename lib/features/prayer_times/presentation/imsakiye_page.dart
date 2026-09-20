import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/mosque_backdrop.dart';
import '../../../shared/models/domain.dart';
import 'providers.dart';

/// Aylık namaz vakti çizelgesi (imsakiye).
///
/// Takvim ekranı bugüne kadar namaz vakitlerine hiç değinmiyordu; kullanıcı
/// yalnızca içinde bulunduğu günün vakitlerini görebiliyordu. Bu ekran ayın
/// tamamını tek tabloda verir.
class ImsakiyePage extends ConsumerStatefulWidget {
  const ImsakiyePage({super.key});

  /// Bugünün satırı; açık renk şeridin üstünde yazı koyudur, okunabilirlik
  /// testi bu satırı ayırır.
  static const todayRowKey = ValueKey('imsakiye-today-row');

  @override
  ConsumerState<ImsakiyePage> createState() => _ImsakiyePageState();
}

/// Tabloda gösterilen vakitler ve başlık anahtarları.
const _columns = <(Prayer, String)>[
  // İlk sütun imsak olarak adlandırılır: oruca başlama vakti budur ve
  // yayımlanan çizelgelerde bu başlık kullanılır.
  (Prayer.fajr, 'imsakiye.fajr'),
  (Prayer.sunrise, 'prayer.sunrise'),
  (Prayer.dhuhr, 'prayer.dhuhr'),
  (Prayer.asr, 'prayer.asr'),
  (Prayer.maghrib, 'prayer.maghrib'),
  (Prayer.isha, 'prayer.isha'),
];

class _ImsakiyePageState extends ConsumerState<ImsakiyePage> {
  late DateTime month;
  final _controller = ScrollController();

  /// Bugüne yalnızca bir kez kaydırılır; kullanıcı listeyi elle kaydırdıktan
  /// sonra her yeniden çizimde geri sıçramamalı.
  bool _scrolledToToday = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _shift(int months) {
    setState(() {
      month = DateTime(month.year, month.month + months);
      _scrolledToToday = true;
    });
    // Başka bir aya geçildiğinde listenin başına dönülür; aksi halde kısa
    // aydan uzun aya geçerken kaydırma konumu anlamsız bir güne denk gelir.
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  /// Satır yüksekliği. Sabit tutulur ki bugünün satırına kaydırma konumu
  /// doğrudan hesaplanabilsin; yazı ölçeğiyle birlikte büyür, içerik
  /// [FittedBox] ile sığdırılır.
  static double rowHeight(BuildContext context) =>
      40 * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);

  /// Açılışta bugünün satırını ekrana getirir. Ayın sonundaki bir günde
  /// çizelge listenin başında açılırsa kullanıcı aradığı günü göremez.
  void _revealToday(int index, double extent) {
    if (_scrolledToToday || index < 0) return;
    _scrolledToToday = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      // Bugün, görünür alanın üst kısmına değil biraz aşağısına gelsin.
      final target = (index * extent) - extent;
      _controller.jumpTo(target.clamp(0, _controller.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final timetable = ref.watch(monthlyTimetableProvider(month));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final extent = rowHeight(context);
    _revealToday(timetable.days.indexWhere((day) => day.date == today), extent);

    // BackdropScaffold: düz Scaffold temanın OPAK zeminini çizer ve
    // arkadaki camiyi tamamen örter.
    return BackdropScaffold(
      title: l10n.text('imsakiye.title'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.text('calendar.previousMonth'),
                    onPressed: () => _shift(-1),
                    color: BackdropPalette.text,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${l10n.month(month.month)} ${month.year}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: BackdropPalette.text),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.text('calendar.nextMonth'),
                    onPressed: () => _shift(1),
                    color: BackdropPalette.text,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            _HeaderRow(),
            Expanded(
              child: ListView.builder(
                controller: _controller,
                itemExtent: extent,
                itemCount: timetable.days.length,
                itemBuilder: (context, index) => _DayRow(
                  times: timetable.days[index],
                  day: index + 1,
                  isToday: timetable.days[index].date == today,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.text('imsakiye.source'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: BackdropPalette.mutedText),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: BackdropPalette.mutedText,
      fontWeight: FontWeight.w600,
    );
    return Container(
      color: const Color(0x24F4EFE4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          _Cell(text: l10n.text('imsakiye.day'), style: style, flex: 3),
          for (final column in _columns)
            _Cell(text: l10n.text(column.$2), style: style),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final PrayerTimes times;
  final int day;
  final bool isToday;

  const _DayRow({
    required this.times,
    required this.day,
    required this.isToday,
  });

  static String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Bugünün satırı açık renk bir şerittir; onun yazısı koyu, diğer
    // satırlarınki perdenin üstünde durduğu için açık olmalı.
    final style = theme.textTheme.bodySmall?.copyWith(
      color: isToday
          ? theme.colorScheme.onPrimaryContainer
          : BackdropPalette.text,
      fontWeight: isToday ? FontWeight.w700 : null,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      key: isToday ? ImsakiyePage.todayRowKey : null,
      decoration: BoxDecoration(
        color: isToday ? theme.colorScheme.primaryContainer : null,
        border: const Border(
          bottom: BorderSide(color: BackdropPalette.divider),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        // Satır satır okunduğunda hangi günün hangi vakti olduğu anlaşılsın.
        label:
            '$day: ${_columns.map((c) => _clock(times.times[c.$1]!)).join(', ')}',
        child: ExcludeSemantics(
          child: Row(
            children: [
              _Cell(text: '$day', style: style, flex: 3),
              for (final column in _columns)
                _Cell(text: _clock(times.times[column.$1]!), style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tablo hücresi.
///
/// Yedi sütun 320 dp genişliğe ancak sığar; büyük yazı ölçeğinde sığmaz.
/// [FittedBox] taşmayı kırpmadan engeller — takvim ızgarasında da aynı
/// çözüm kullanılıyor.
class _Cell extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int flex;

  const _Cell({required this.text, this.style, this.flex = 4});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, style: style, maxLines: 1),
      ),
    ),
  );
}
