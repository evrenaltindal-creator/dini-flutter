import 'dart:io';

import 'package:dini_flutter/app/router.dart';
import 'package:dini_flutter/core/layout/book_layout.dart';
import 'package:dini_flutter/core/layout/book_text_reader.dart';
import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/calendar/presentation/calendar_page.dart';
import 'package:dini_flutter/features/calendar/presentation/daily_leaf_page.dart';
import 'package:dini_flutter/features/home/presentation/mosque_scene.dart';
import 'package:dini_flutter/features/prayer_times/data/city_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/timezone_service.dart';
import 'package:dini_flutter/features/prayer_times/presentation/providers.dart';
import 'package:dini_flutter/features/quran/data/quran_book.dart';
import 'package:dini_flutter/features/quran/presentation/mushaf_page.dart';
import 'package:dini_flutter/features/quran/presentation/quran_reader_page.dart';
import 'package:dini_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_fixture.dart';

late QuranBook book;
late String cities;

void main() {
  setUpAll(() async {
    TimezoneService.initialize();
    cities = File(CityRepository.assetKey).readAsStringSync();
    book = await loadQuranBookFromDisk();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<MemoryStorage> open(
    WidgetTester tester, {
    String route = '/',
    String language = 'tr',
    Size size = const Size(820, 650),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final storage = MemoryStorage()..values['dini.quran.lastPage'] = '42';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          cityRepositoryProvider.overrideWithValue(
            CityRepository(loadAsset: (_) async => cities),
          ),
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 14, 12)),
          localeProvider.overrideWith((ref) => Locale(language)),
          quranBookProvider.overrideWith((ref) => book),
        ],
        child: DiniApp(router: createRouter(initialLocation: route)),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  testWidgets(
    'opening goes directly to saved Qur’an; closing preserves scene and position',
    (tester) async {
      final storage = await open(tester, size: const Size(405, 650));
      expect(find.byType(HomePage), findsOneWidget);
      final sceneState = tester.state(find.byType(MosqueScene));
      tester.view.physicalSize = const Size(820, 650);
      await tester.pumpAndSettle();
      expect(find.byType(QuranReaderPage), findsOneWidget);
      expect(storage.values['dini.quran.lastPage'], '42');
      final first = find.byWidgetPredicate(
        (w) => w is MushafPage && w.page == 41,
      );
      final second = find.byWidgetPredicate(
        (w) => w is MushafPage && w.page == 42,
      );
      expect(
        tester.getCenter(first).dx,
        greaterThan(tester.getCenter(second).dx),
      );
      expect(
        identical(sceneState, tester.state(find.byType(MosqueScene))),
        isTrue,
      );
      await tester.tap(find.byTooltip('Sonraki sayfa'));
      await tester.pumpAndSettle();
      expect(storage.values['dini.quran.lastPage'], '43');
      tester.view.physicalSize = const Size(405, 650);
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      tester.view.physicalSize = const Size(820, 650);
      await tester.pumpAndSettle();
      expect(storage.values['dini.quran.lastPage'], '43');
      expect(
        identical(sceneState, tester.state(find.byType(MosqueScene))),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['tr', 'en', 'ar']) {
    testWidgets(
      '$language: expanded navigation stays on right and book stays readable',
      (tester) async {
        await open(tester, language: language);
        final rail = find.byKey(const ValueKey('book-right-navigation'));
        expect(tester.getRect(rail).left, greaterThan(700));
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(MushafPage), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'calendar has both pages; selecting month day updates daily leaf',
    (tester) async {
      await open(tester, route: '/calendar');
      expect(find.byType(CalendarPage), findsOneWidget);
      expect(find.byType(DailyLeafPage), findsOneWidget);
      expect(find.byType(CalendarModeSwitch), findsNothing);
      final day = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label?.startsWith('15 Kasım ') ?? false),
      );
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DailyLeafPage>(find.byType(DailyLeafPage)).selectedDate,
        DateTime(2026, 11, 15),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'worship reflows real text into two papers; Arabic dua starts right',
    (tester) async {
      await open(tester, route: '/worship');
      await tester.tap(find.widgetWithText(Tab, 'Namaz'));
      await tester.pumpAndSettle();
      expect(find.byType(BookPaper), findsNWidgets(2));
      await tester.tap(find.widgetWithText(TextButton, 'Dua'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BookSpread>(find.byType(BookSpread).first)
            .readingDirection,
        TextDirection.rtl,
      );
      final reader = tester.widget<BookTextReader>(find.byType(BookTextReader));
      expect(reader.text, contains('سُبْحَانَكَ'));
      expect(tester.takeException(), isNull);
    },
  );

  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 1.6, 2.2]) {
      test('pagination retains every grapheme at $direction, scale $scale', () {
        final text =
            (direction == TextDirection.rtl
                ? 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n\n'
                : 'Okunabilir metin, ayırmadan devam eder. 👨‍👩‍👧‍👦\n\n') *
            30;
        const style = TextStyle(inherit: false, fontSize: 17, height: 1.65);
        final pages = paginateBookText(
          text: text,
          width: 260,
          height: 340,
          style: style,
          direction: direction,
          scaler: TextScaler.linear(scale),
          locale: const Locale('tr'),
        );
        expect(pages.map((p) => p.text).join(), text);
        final boundaries = <int>{0};
        for (final char in text.characters) {
          boundaries.add(boundaries.last + char.length);
        }
        for (final page in pages) {
          expect(boundaries, contains(page.start));
          final painter = TextPainter(
            text: TextSpan(text: page.text, style: style),
            textDirection: direction,
            textScaler: TextScaler.linear(scale),
          )..layout(maxWidth: 260);
          expect(painter.height, lessThanOrEqualTo(340));
          painter.dispose();
        }
      });
    }
  }
}
