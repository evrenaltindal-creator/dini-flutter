import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../prayer_times/presentation/providers.dart';
import '../domain/islamic_calendar.dart';
import '../domain/religious_events.dart';
import 'daily_leaf_page.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  /// Seçili gün hücresi; okunabilirlik testi onu ayırt edebilsin diye.
  static const selectedDayKey = ValueKey('calendar-selected-day');
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  /// Kullanıcının hicri kaydırması takvime de uygulanır; aksi halde ana ekran
  /// ile takvim ekranı farklı hicri tarih gösterir.
  IslamicCalendar get calendar =>
      ref.watch(effectivePrayerSettingsProvider).calendar;
  ReligiousEvents get events => ReligiousEvents(calendar: calendar);
  late DateTime month;
  late DateTime selected;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
    selected = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = firstWeekday + daysInMonth;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Bu ekranın başlığı, ızgarası ve açıklaması kart içinde değil,
          // doğrudan cami perdesinin üstünde duruyor; temanın koyu yazı
          // renkleriyle aydınlık kipte okunmuyorlardı.
          Text(
            l10n.text('nav.calendar'),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: BackdropPalette.text),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('calendar.disclaimer'),
            style: TextStyle(color: BackdropPalette.mutedText),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                tooltip: l10n.text('calendar.previousMonth'),
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                color: BackdropPalette.text,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${l10n.month(month.month)} ${month.year}',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: BackdropPalette.text),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.text('calendar.nextMonth'),
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
                color: BackdropPalette.text,
                icon: const Icon(Icons.chevron_right),
              ),
              TextButton(
                onPressed: _goToday,
                style: TextButton.styleFrom(
                  foregroundColor: BackdropPalette.text,
                ),
                child: Text(l10n.text('calendar.today')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children:
                List.generate(7, (index) => l10n.text('weekday.${index + 1}'))
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: BackdropPalette.mutedText),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Hücre yüksekliği yazı ölçeğiyle birlikte artmalı. Sabit oranda
            // büyük yazıda gün numarası, hicri gün ve yıldız hücreye sığmayıp
            // dikeyde taşıyordu.
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: .78 / _textScale(context).clamp(1.0, 2.0),
            ),
            itemCount: ((cells + 6) ~/ 7) * 7,
            itemBuilder: (context, index) {
              final dayNumber = index - firstWeekday + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(month.year, month.month, dayNumber);
              final hijri = calendar.hijri(date);
              final marked = events.on(date).isNotEmpty;
              final isSelected = date == selected;
              return Semantics(
                button: true,
                label:
                    '$dayNumber ${l10n.month(month.month)} ${hijri.label}${marked ? ', ${l10n.text('calendar.religiousDay')}' : ''}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => selected = date),
                  child: Container(
                    // Seçili hücrenin yazısı bilerek koyudur (açık renk bir
                    // kutunun içindedir); okunabilirlik testi onu bu
                    // anahtarla ayırır.
                    key: isSelected ? CalendarPage.selectedDayKey : null,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    // Hücre oranı yazı ölçeğiyle büyüse de uç ölçeklerde
                    // içerik yine sığmayabiliyor; scaleDown taşmayı kesin
                    // olarak engeller, kırpmaz.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              // Seçili gün açık renk bir kutudadır; yazısı
                              // o kutunun rengine göre koyulaşır.
                              color: isSelected
                                  ? Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                  : BackdropPalette.text,
                            ),
                          ),
                          Text(
                            '${hijri.day}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: isSelected
                                      ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                      : BackdropPalette.mutedText,
                                ),
                          ),
                          if (marked)
                            Icon(
                              Icons.star,
                              size: 12,
                              color: isSelected
                                  ? Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                  : BackdropPalette.mutedText,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Takvim bugüne kadar namaz vaktine hiç değinmiyordu; aylık
          // çizelge buradan açılır.
          FilledButton.tonalIcon(
            onPressed: () => context.push('/imsakiye'),
            icon: const Icon(Icons.schedule_outlined),
            label: Text(l10n.text('imsakiye.open')),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/leaf'),
            icon: const Icon(Icons.auto_stories_outlined),
            label: Text(l10n.text('leaf.today')),
          ),
          const SizedBox(height: 16),
          _selectedPanel(context),
        ],
      ),
    );
  }

  /// Kullanıcının seçtiği yazı ölçeği katsayısı.
  double _textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) / 14;

  Widget _selectedPanel(BuildContext context) {
    final h = calendar.hijri(selected);
    final dayEvents = events.on(selected);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.text('calendar.selectedDay'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${selected.day} ${context.l10n.month(selected.month)} ${selected.year}',
            ),
            Text(context.l10n.text('home.hijri', {'date': h.label})),
            if (dayEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.l10n.text('calendar.noEvent')),
              )
            else
              ...dayEvents.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(context.l10n.text('event.${event.id}')),
                ),
              ),
            const SizedBox(height: 8),
            Text(context.l10n.text('calendar.dateNotice')),
            const SizedBox(height: 12),
            // Seçilen günün takvim yaprağı.
            FilledButton.tonalIcon(
              onPressed: () => context.push(DailyLeafPage.routeFor(selected)),
              icon: const Icon(Icons.auto_stories_outlined),
              label: Text(context.l10n.text('leaf.open')),
            ),
          ],
        ),
      ),
    );
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      month = DateTime(now.year, now.month);
      selected = DateTime(now.year, now.month, now.day);
    });
  }
}
