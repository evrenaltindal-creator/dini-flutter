import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../shared/models/domain.dart';
import '../../content/domain/content_repository.dart';
import '../../content/presentation/content_card.dart';
import '../../home/presentation/mosque_backdrop.dart';
import '../../prayer_times/domain/timezone_service.dart';
import '../../prayer_times/presentation/providers.dart';
import '../domain/folk_calendar.dart';
import '../domain/religious_events.dart';

/// Kâğıdın rengi ve mürekkepleri.
///
/// Uygulama koyu temayla çizilir; kartın içindeki yazı varsayılan olarak AÇIK
/// renktir ve krem kâğıtta okunmaz. Yapraktaki her yazının rengi bu yüzden
/// buradan açıkça verilir (`daily_leaf_test.dart` karşıtlığı ölçer).
const leafPaper = Color(0xFFF7F1E3);
const leafInk = Color(0xFF1E2522);
const leafMutedInk = Color(0xFF5A605C);
const leafRed = Color(0xFFB3261E);

/// Günün takvim yaprağı.
///
/// Duvar takvimlerinin yırtılan yaprağı gibi: büyük gün rakamı, gün adı,
/// Hicri ve Rumi tarih, Hızır/Kasım günü, yılın kaçıncı günü, o günün namaz
/// vakitleri, varsa dini gün ve günün ayet/hadis/duası. Yapraklar yana
/// kaydırılarak çevrilir.
///
/// "Tarihte bugün" ya da benzeri içerik bilerek yok: doğrulanamayan bilgi
/// dini bir uygulamaya konmaz.
class DailyLeafPage extends ConsumerStatefulWidget {
  /// Açılacak gün; verilmezse seçilen şehrin bugünü.
  final DateTime? initialDate;

  /// Takvim sekmesinin içinde mi? Sekme kabuğu cami perdesini ve
  /// Scaffold'u zaten çizer; ikinci perde sahneyi koyulaştırırdı. Sekmede
  /// üstte "Günün yaprağı / Aylık takvim" geçişi durur.
  final bool embedded;

  const DailyLeafPage({super.key, this.initialDate, this.embedded = false});

  /// Takvim sekmesinin yolları: önce yaprak, sonra aylık takvim.
  static const tabRoute = '/calendar';
  static const monthRoute = '/calendar/month';

  /// Yaprağın kağıdı; testler karşıtlığı buradan ölçer.
  static const paperKey = ValueKey('daily-leaf-paper');

  static String routeFor(DateTime date) =>
      '/leaf/${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Yoldaki tarihi çözer; geçersizse null.
  static DateTime? parse(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    // 2026-02-31 gibi bir tarih DateTime'da sessizce Mart'a kayar.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  @override
  ConsumerState<DailyLeafPage> createState() => _DailyLeafPageState();
}

class _DailyLeafPageState extends ConsumerState<DailyLeafPage> {
  /// Sayfa görünümü iki yöne de "sonsuz" kaydırılır; ortadaki sayfa ilk
  /// gündür.
  static const _center = 100000;

  late final DateTime origin;
  late final PageController controller;

  @override
  void initState() {
    super.initState();
    origin = widget.initialDate ?? _cityToday();
    controller = PageController(initialPage: _center);
  }

  /// Seçilen şehrin bugünü: cihazın günü değil (uygulamanın geri kalanı gibi).
  DateTime _cityToday() {
    final settings = ref.read(effectivePrayerSettingsProvider);
    final now = TimezoneService.inLocation(
      settings.location.timezoneId ?? 'Europe/Istanbul',
      ref.read(clockProvider)(),
    );
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateAt(int index) =>
      DateTime(origin.year, origin.month, origin.day + index - _center);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _turn(int pages) => controller.animateToPage(
    (controller.page?.round() ?? _center) + pages,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = PageView.builder(
      controller: controller,
      itemBuilder: (context, index) => _Leaf(
        date: _dateAt(index),
        onPrevious: () => _turn(-1),
        onNext: () => _turn(1),
      ),
    );
    if (widget.embedded) {
      return SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
              child: CalendarModeSwitch(showingLeaf: true),
            ),
            Expanded(child: pages),
          ],
        ),
      );
    }
    return BackdropScaffold(
      title: l10n.text('leaf.title'),
      body: SafeArea(child: pages),
    );
  }
}

class _Leaf extends ConsumerWidget {
  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _Leaf({
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(effectivePrayerSettingsProvider);
    final calendar = settings.calendar;
    final hijri = calendar.hijri(date);
    final rumi = RumiDate.fromGregorian(date);
    final season = folkSeasonDay(date);
    final year = dayOfYear(date);
    final events = ReligiousEvents(calendar: calendar).on(date);
    final times = ref
        .watch(monthlyTimetableProvider(DateTime(date.year, date.month)))
        .forDay(date);
    final content = OfflineContentRepository.dailyFor(date);
    // Cuma ve dini günler kırmızı basılır; takvimlerin geleneği.
    final special = date.weekday == DateTime.friday || events.isNotEmpty;

    String clock(DateTime value) {
      final hour = settings.use24Hour
          ? value.hour
          : (value.hour % 12 == 0 ? 12 : value.hour % 12);
      final minute = value.minute.toString().padLeft(2, '0');
      return settings.use24Hour
          ? '${hour.toString().padLeft(2, '0')}:$minute'
          : '$hour:$minute';
    }

    TextStyle style(double size, {Color color = leafInk, FontWeight? weight}) =>
        TextStyle(color: color, fontSize: size, fontWeight: weight);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 28),
      children: [
        Card(
          key: DailyLeafPage.paperKey,
          color: leafPaper,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Yaprağın üst şeridi: ay ve yıl.
              ColoredBox(
                color: special ? leafRed : leafInk,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '${l10n.month(date.month)} ${date.year}',
                    textAlign: TextAlign.center,
                    style: style(18, color: leafPaper, weight: FontWeight.w700),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    Text(
                      '${date.day}',
                      style: style(
                        112,
                        color: special ? leafRed : leafInk,
                        weight: FontWeight.w800,
                      ).copyWith(height: 1.05),
                    ),
                    Text(
                      l10n.text('weekdayLong.${date.weekday}'),
                      style: style(
                        22,
                        color: special ? leafRed : leafInk,
                        weight: FontWeight.w600,
                      ),
                    ),
                    for (final event in events)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l10n.text('event.${event.id}'),
                          textAlign: TextAlign.center,
                          style: style(
                            17,
                            color: leafRed,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const Divider(height: 28, color: Color(0x33000000)),
                    _DateLine(
                      label: l10n.text('leaf.hijri'),
                      value:
                          '${hijri.day} ${l10n.text('hijriMonth.${hijri.month}')} ${hijri.year}',
                    ),
                    _DateLine(
                      label: l10n.text('leaf.rumi'),
                      value:
                          '${rumi.day} ${l10n.text('rumiMonth.${rumi.month}')} ${rumi.year}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        l10n.text(
                          season.season == FolkSeason.hizir
                              ? 'leaf.hizir'
                              : 'leaf.kasim',
                          {'day': season.day},
                        ),
                        l10n.text('leaf.dayOfYear', {
                          'day': year.dayOfYear,
                          'left': year.daysLeft,
                        }),
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: style(14, color: leafMutedInk),
                    ),
                    if (times != null) ...[
                      const Divider(height: 28, color: Color(0x33000000)),
                      Text(
                        l10n.text('leaf.times'),
                        style: style(15, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 18,
                        runSpacing: 10,
                        children: [
                          for (final (prayer, key) in _leafColumns)
                            SizedBox(
                              width: 88,
                              child: Column(
                                children: [
                                  Text(
                                    l10n.text(key),
                                    style: style(13, color: leafMutedInk),
                                  ),
                                  Text(
                                    clock(times.times[prayer]!),
                                    style: style(19, weight: FontWeight.w700)
                                        .copyWith(
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      l10n.text('leaf.rumiNotice'),
                      textAlign: TextAlign.center,
                      style: style(11, color: leafMutedInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Yön duyarlı: Arapça'da "önceki" sağdadır.
            IconButton.filledTonal(
              tooltip: l10n.text('leaf.previous'),
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton.filledTonal(
              tooltip: l10n.text('leaf.next'),
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DailyContentCard(
          title: switch (content) {
            VerseContent() => l10n.text('home.verse'),
            HadithContent() => l10n.text('home.hadith'),
            DuaContent() => l10n.text('home.prayer'),
          },
          content: content,
          glass: true,
        ),
      ],
    );
  }
}

/// Yapraktaki vakitler; imsakiye ile aynı başlıklar.
const _leafColumns = <(Prayer, String)>[
  (Prayer.fajr, 'imsakiye.fajr'),
  (Prayer.sunrise, 'prayer.sunrise'),
  (Prayer.dhuhr, 'prayer.dhuhr'),
  (Prayer.asr, 'prayer.asr'),
  (Prayer.maghrib, 'prayer.maghrib'),
  (Prayer.isha, 'prayer.isha'),
];

class _DateLine extends StatelessWidget {
  final String label;
  final String value;

  const _DateLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$label  ',
          style: const TextStyle(color: leafMutedInk, fontSize: 15),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: leafInk,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Takvim sekmesinin üstündeki geçiş: günün yaprağı ya da aylık takvim.
///
/// Kullanıcı isteği: takvime girince önce yaprak gelsin.
class CalendarModeSwitch extends StatelessWidget {
  final bool showingLeaf;

  const CalendarModeSwitch({super.key, required this.showingLeaf});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: true,
            icon: const Icon(Icons.auto_stories_outlined),
            label: Text(l10n.text('leaf.title')),
          ),
          ButtonSegment(
            value: false,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(l10n.text('calendar.monthView')),
          ),
        ],
        selected: {showingLeaf},
        onSelectionChanged: (value) => context.go(
          value.first ? DailyLeafPage.tabRoute : DailyLeafPage.monthRoute,
        ),
      ),
    );
  }
}
