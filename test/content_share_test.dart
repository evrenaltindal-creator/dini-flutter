import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/content/domain/content_repository.dart';
import 'package:dini_flutter/features/content/presentation/content_card.dart';
import 'package:dini_flutter/shared/models/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Günün duası"ndaki paylaş düğmesi hiçbir şey açmıyordu.
///
/// share_plus, paylaşım penceresi balon (popover) olarak açılacaksa düğmenin
/// ekrandaki yerini ister; verilmezse hata döner ve pencere hiç açılmaz. Bu
/// iPad'de hep böyleydi, iOS 26'da iPhone'da da öyle. Düğme yerini hiç
/// göndermiyordu ve hata yutuluyordu.
const _channel = MethodChannel('dev.fluttercommunity.plus/share');

Widget _app({required Widget child}) => MaterialApp(
  locale: const Locale('tr'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: Center(child: child)),
);

const _dua = DuaContent(
  DailyDua(
    'رَبَّنَا آتِنَا',
    'Rabbenâ âtinâ',
    'Rabbimiz, bize dünyada iyilik ver.',
    'Bakara 201',
  ),
);

void main() {
  testWidgets('paylaşım düğmenin ekrandaki yerini taşır', (tester) async {
    MethodCall? sent;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      sent = call;
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );

    await tester.pumpWidget(
      _app(
        child: const DailyContentCard(title: 'Günün duası', content: _dua),
      ),
    );
    await tester.tap(find.byTooltip('Paylaş'));
    await tester.pumpAndSettle();

    expect(sent, isNotNull, reason: 'Paylaşım çağrısı hiç yapılmadı.');
    final arguments = (sent!.arguments as Map).cast<String, Object?>();
    expect(arguments['text'], contains('Rabbimiz'));
    for (final key in ['originX', 'originY', 'originWidth', 'originHeight']) {
      expect(
        arguments[key],
        isNotNull,
        reason:
            'Paylaşım $key taşımıyor; balon olarak açılan pencere '
            '(iPad, iOS 26) hata verip hiç açılmaz.',
      );
    }
    expect(arguments['originWidth'] as double, greaterThan(0));
    expect(arguments['originHeight'] as double, greaterThan(0));
  });

  testWidgets('paylaşılamazsa metin kopyalanır ve söylenir', (tester) async {
    // Hata sessizce yutuluyordu: kullanıcı düğmeye basıyor, hiçbir şey
    // olmuyordu.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => throw PlatformException(code: 'error'),
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      _app(
        child: const DailyContentCard(title: 'Günün duası', content: _dua),
      ),
    );
    await tester.tap(find.byTooltip('Paylaş'));
    await tester.pumpAndSettle();

    expect(copied, contains('Rabbimiz'));
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
