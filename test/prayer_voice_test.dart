import 'package:dini_flutter/features/worship/data/prayer_voice.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Namaz hocasının sesi (kullanıcı: "ses daha iyi olabilir mi?").
///
/// Telefonun en iyi Arapça sesi seçilir; internet isteyen ses seçilmez,
/// çünkü metni uzaktaki sunucuya gönderir.
Map<String, String> _voice(
  String name,
  String locale,
  String quality, {
  bool network = false,
  String features = '',
}) => {
  'name': name,
  'locale': locale,
  'quality': quality,
  'network_required': network ? '1' : '0',
  'features': features,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ses seçimi', () {
    test('en yüksek kaliteli Arapça ses seçilir', () {
      final voice = pickArabicVoice([
        _voice('tr-basic', 'tr-TR', 'premium'),
        _voice('ar-basic', 'ar-SA', 'default'),
        _voice('ar-enhanced', 'ar-SA', 'enhanced'),
        _voice('ar-premium', 'ar-001', 'premium'),
      ]);
      expect(voice?['name'], 'ar-premium');
      expect(readinessOf(voice), VoiceReadiness.natural);
    });

    test('internet isteyen ve indirilmemiş ses alınmaz', () {
      final voice = pickArabicVoice([
        _voice('ar-network', 'ar-XA', 'very high', network: true),
        _voice('ar-missing', 'ar-XA', 'very high', features: 'notInstalled'),
        _voice('ar-local', 'ar-XA', 'normal'),
      ]);
      expect(voice?['name'], 'ar-local');
      expect(readinessOf(voice), VoiceReadiness.basic);
    });

    test('eşit kalitede Suudi Arapçası önce gelir', () {
      final voice = pickArabicVoice([
        _voice('egypt', 'ar_EG', 'enhanced'),
        _voice('saudi', 'ar_SA', 'enhanced'),
      ]);
      expect(voice?['name'], 'saudi');
    });

    test('Arapça ses yoksa hiçbiri', () {
      final voice = pickArabicVoice([_voice('tr', 'tr-TR', 'premium')]);
      expect(voice, isNull);
      expect(readinessOf(voice), VoiceReadiness.unavailable);
    });

    test('hız soluğu da kısaltır', () {
      expect(linePauseFor(2), linePauseFor(1) ~/ 2);
      expect(speechRateFor(1), lessThan(.5));
      expect(speechRateFor(10), 1.0);
    });
  });

  group('telefonun konuşma motoru', () {
    const channel = MethodChannel('flutter_tts');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'getVoices') {
              return [
                _voice('ar-basic', 'ar-SA', 'normal'),
                _voice('ar-good', 'ar-SA', 'very high'),
                _voice('ar-cloud', 'ar-SA', 'very high', network: true),
              ];
            }
            return 1;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('en iyi yerel ses kurulur, âyetler ayrı ayrı okunur', () async {
      final voice = DeviceArabicVoice();
      expect(await voice.prepare(), VoiceReadiness.natural);
      final setVoice = calls.lastWhere((c) => c.method == 'setVoice');
      expect((setVoice.arguments as Map)['name'], 'ar-good');

      calls.clear();
      await voice.speak('سطر أول\nسطر ثان\n', speed: 4);
      expect(calls.where((c) => c.method == 'speak').map((c) => c.arguments), [
        'سطر أول',
        'سطر ثان',
      ]);
    });

    test('durdurulunca kalan satırlar okunmaz', () async {
      final voice = DeviceArabicVoice();
      await voice.prepare();
      calls.clear();
      final speaking = voice.speak('bir\niki\nüç', speed: 1);
      await voice.stop();
      await speaking;
      expect(calls.where((c) => c.method == 'speak').length, lessThan(3));
    });
  });
}
