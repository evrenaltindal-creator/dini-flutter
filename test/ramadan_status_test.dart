import 'package:dini_flutter/features/calendar/domain/islamic_calendar.dart';
import 'package:dini_flutter/features/calendar/domain/ramadan_status.dart';
import 'package:dini_flutter/features/prayer_times/data/prayer_settings_repository.dart';
import 'package:dini_flutter/features/prayer_times/domain/prayer_settings.dart';
import 'package:dini_flutter/core/storage/local_storage.dart';
import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/calendar/presentation/ramadan_headline.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements LocalStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

const _calendar = IslamicCalendar();

/// Takvimde ileriye doğru arayarak hicri ayın ilk gününü bulur.
DateTime _firstDayOf(int hijriMonth, {IslamicCalendar calendar = _calendar}) {
  var date = DateTime(2026);
  for (var step = 0; step < 2000; step++) {
    final hijri = calendar.hijri(date);
    if (hijri.month == hijriMonth && hijri.day == 1) return date;
    date = date.add(const Duration(days: 1));
  }
  fail('$hijriMonth. hicri ayın başı bulunamadı.');
}

void main() {
  final ramadanStart = _firstDayOf(9);

  group('Ramazan içinde', () {
    test('ilk gün birinci gün olarak bildirilir', () {
      final status = ramadanStatus(ramadanStart);
      expect(status.phase, RamadanPhase.during);
      expect(status.dayOfRamadan, 1);
      expect(status.isFasting, isTrue);
      expect(status.isVisible, isTrue);
    });

    test('gün sayısı her gün bir artar', () {
      for (var day = 1; day <= 20; day++) {
        final status = ramadanStatus(ramadanStart.add(Duration(days: day - 1)));
        expect(
          status.dayOfRamadan,
          day,
          reason: 'Ramazan $day. günü yanlış sayılıyor.',
        );
      }
    });

    test('yirmi birinci günde son on geceye geçer', () {
      expect(
        ramadanStatus(ramadanStart.add(const Duration(days: 19))).phase,
        RamadanPhase.during,
      );
      final lastTen = ramadanStatus(ramadanStart.add(const Duration(days: 20)));
      expect(lastTen.phase, RamadanPhase.lastTen);
      expect(lastTen.dayOfRamadan, 21);
      // Son on gecede de oruç tutulur; faz değişimi bunu bozmamalı.
      expect(lastTen.isFasting, isTrue);
    });
  });

  group('Ramazan öncesi', () {
    test('bir gün önce kalan gün birdir', () {
      final status = ramadanStatus(
        ramadanStart.subtract(const Duration(days: 1)),
      );
      expect(status.phase, RamadanPhase.approaching);
      expect(status.daysRemaining, 1);
      expect(status.isFasting, isFalse);
    });

    test('geri sayım penceresi boyunca gün gün azalır', () {
      for (var ahead = 1; ahead <= ramadanCountdownWindow; ahead++) {
        final status = ramadanStatus(
          ramadanStart.subtract(Duration(days: ahead)),
        );
        expect(
          status.daysRemaining,
          ahead,
          reason: '$ahead gün kala sayım yanlış.',
        );
        expect(status.phase, RamadanPhase.approaching);
      }
    });

    test('pencerenin dışında geri sayım gösterilmez', () {
      final status = ramadanStatus(
        ramadanStart.subtract(const Duration(days: ramadanCountdownWindow + 1)),
      );
      expect(status.phase, RamadanPhase.far);
      expect(
        status.isVisible,
        isFalse,
        reason: 'Yılın çoğunda ana ekranda Ramazan kartı durmamalı.',
      );
      expect(status.daysRemaining, isNull);
    });
  });

  group('bayram', () {
    test('Ramazan biter bitmez bayram fazına geçilir', () {
      final shawwal = _firstDayOf(10);
      final status = ramadanStatus(shawwal);
      expect(status.phase, RamadanPhase.eid);
      expect(
        status.isFasting,
        isFalse,
        reason: 'Bayram günü oruç günü olarak işaretlenemez.',
      );
    });

    test('bayramın üçüncü gününden sonra kart kalkar', () {
      final shawwal = _firstDayOf(10);
      expect(
        ramadanStatus(shawwal.add(const Duration(days: 2))).phase,
        RamadanPhase.eid,
      );
      expect(
        ramadanStatus(shawwal.add(const Duration(days: 3))).phase,
        isNot(RamadanPhase.eid),
      );
    });
  });

  group('hicri düzeltme geri sayıma uygulanır', () {
    // Takvim tabulardır ve resmî ilandan bir gün sapabilir. Düzeltme geri
    // sayıma ulaşmazsa kullanıcı, bildirimlerin planlandığı günden farklı
    // bir gün görür.
    test('bir gün ileri kaydırma Ramazan\'ı bir gün erken başlatır', () {
      const forward = IslamicCalendar(dayOffset: 1);
      final dayBefore = ramadanStart.subtract(const Duration(days: 1));

      expect(ramadanStatus(dayBefore).phase, RamadanPhase.approaching);
      expect(
        ramadanStatus(dayBefore, calendar: forward).phase,
        RamadanPhase.during,
        reason: 'İleri kaydırmada Ramazan bir gün erken başlamalı.',
      );
      expect(ramadanStatus(dayBefore, calendar: forward).dayOfRamadan, 1);
    });

    test('bir gün geri kaydırma Ramazan\'ı bir gün geciktirir', () {
      const back = IslamicCalendar(dayOffset: -1);
      expect(ramadanStatus(ramadanStart).phase, RamadanPhase.during);

      final shifted = ramadanStatus(ramadanStart, calendar: back);
      expect(shifted.phase, RamadanPhase.approaching);
      expect(shifted.daysRemaining, 1);
    });

    test('düzeltmesiz takvim değişmeden kalır', () {
      const none = IslamicCalendar();
      expect(none.hijri(ramadanStart).month, 9);
      expect(none.hijri(ramadanStart).day, 1);
    });
  });

  group('ayarlardaki düzeltme kalıcı', () {
    test('kaydedilen kaydırma geri okunur ve takvime geçer', () async {
      final storage = _MemoryStorage();
      final repository = PrayerSettingsRepository(storage);
      await repository.save(const PrayerSettings(hijriOffset: 1));

      final loaded = await repository.load();
      expect(loaded.hijriOffset, 1);
      expect(
        loaded.calendar.dayOffset,
        1,
        reason: 'Ayar kaydedildi ama takvime ulaşmıyor.',
      );
    });

    test('varsayılan düzeltme sıfırdır', () async {
      final loaded = await PrayerSettingsRepository(_MemoryStorage()).load();
      expect(loaded.hijriOffset, 0);
    });

    test('bozuk değer takvimi saatlerce kaydırmaz', () async {
      // Elle düzenlenmiş ya da bozulmuş bir kayıt uygulamayı başka bir aya
      // taşımamalı.
      final storage = _MemoryStorage();
      await PrayerSettingsRepository(storage).save(const PrayerSettings());
      storage.values[PrayerSettingsRepository.key] = storage
          .values[PrayerSettingsRepository.key]!
          .replaceFirst('"hijriOffset":0', '"hijriOffset":400');

      final loaded = await PrayerSettingsRepository(storage).load();
      expect(loaded.hijriOffset, inInclusiveRange(-1, 1));
    });
  });

  group('ana ekran metni', () {
    // Metin ana ekranın içinde özel bir yöntemdeyken test edilemiyordu:
    // cihazın gerçek tarihi Ramazan'a denk gelmediği sürece hiç çizilmiyordu.
    AppLocalizations l10n(String language) =>
        AppLocalizations(Locale(language));

    test('geri sayım kalan günü yazar', () {
      const status = RamadanStatus(
        phase: RamadanPhase.approaching,
        daysRemaining: 12,
      );
      final text = ramadanHeadline(status, l10n('tr'));
      expect(text, contains('12'));
      expect(
        text,
        isNot(contains('{days}')),
        reason: 'Yer tutucu değiştirilmemiş.',
      );
    });

    test('üç dilde de ayrı ve dolu metin verir', () {
      for (final phase in [RamadanPhase.approaching, RamadanPhase.eid]) {
        final texts = {
          for (final language in ['tr', 'en', 'ar'])
            language: ramadanHeadline(
              RamadanStatus(phase: phase, daysRemaining: 5),
              l10n(language),
            ),
        };
        expect(
          texts.values.toSet(),
          hasLength(3),
          reason: '$phase için diller aynı metni veriyor: $texts',
        );
        for (final value in texts.values) {
          expect(value.trim(), isNotEmpty);
          expect(
            value,
            isNot(startsWith('ramadan.')),
            reason: 'Anahtar çözülmemiş: $value',
          );
        }
      }
    });

    test('oruç günlerinde ve uzak günlerde boş döner', () {
      // Bu fazlarda ana ekran sahur/iftar mesajını gösterir; iki metnin
      // birden çıkması satırın iki kez yazılması demek olurdu.
      for (final phase in [
        RamadanPhase.during,
        RamadanPhase.lastTen,
        RamadanPhase.far,
      ]) {
        expect(
          ramadanHeadline(RamadanStatus(phase: phase), l10n('tr')),
          isEmpty,
          reason: '$phase için geri sayım satırı çizilmemeli.',
        );
      }
    });
  });
}
