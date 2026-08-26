import 'package:flutter/material.dart';

import '../domain/islamic_calendar.dart';
import '../domain/religious_events.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final calendar = const IslamicCalendar();
  final events = const ReligiousEvents();
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
    final firstWeekday = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = firstWeekday + daysInMonth;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Takvim', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Hicri tarih offline tabular hesaplama ile gösterilir; gözlemlenen tarihler bölgeye ve otoriteye göre değişebilir.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                tooltip: 'Önceki ay',
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_months[month.month]} ${month.year}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sonraki ay',
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
              TextButton(onPressed: _goToday, child: const Text('Bugün')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: _weekdays
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: Theme.of(context).textTheme.labelSmall,
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: .78,
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
                    '$dayNumber ${_months[month.month]} ${hijri.label}${marked ? ', dini gün' : ''}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => selected = date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${hijri.day}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (marked) const Icon(Icons.star, size: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _selectedPanel(context),
        ],
      ),
    );
  }

  Widget _selectedPanel(BuildContext context) {
    final h = calendar.hijri(selected);
    final dayEvents = events.on(selected);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seçili gün', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${selected.day} ${_months[selected.month]} ${selected.year}'),
            Text('Hicri ${h.label}'),
            if (dayEvents.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Bu gün için kayıtlı dini etkinlik yok.'),
              )
            else
              ...dayEvents.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(event.name),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Tarihler hesaplanmış İslami takvim tarihidir; yerel ilanlarla farklılık gösterebilir.',
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

  static const _months = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  static const _weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
}
