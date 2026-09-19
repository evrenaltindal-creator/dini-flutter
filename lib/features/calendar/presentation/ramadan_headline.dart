import '../../../core/localization/app_localizations.dart';
import '../domain/ramadan_status.dart';

/// Ramazan dışındaki günlerde ana ekranda gösterilen tek satır.
///
/// Ana ekranın içinde özel bir yöntem olarak durduğunda test edilemiyordu:
/// metin cihazın gerçek tarihine bağlıydı ve Ramazan'a denk gelen bir günü
/// widget testinde kurmanın yolu yoktu. Burada saf bir işlev olarak durur.
///
/// Oruç günlerinde ana ekran sahur/iftar mesajını gösterir; bu işlev yalnızca
/// yaklaşma ve bayram metinlerini verir.
String ramadanHeadline(RamadanStatus status, AppLocalizations l10n) =>
    switch (status.phase) {
      RamadanPhase.eid => l10n.text('ramadan.eid'),
      RamadanPhase.approaching => l10n.text('ramadan.countdown', {
        'days': status.daysRemaining ?? 0,
      }),
      // Oruç günlerinde ve Ramazan uzaktayken bu satır kullanılmaz.
      RamadanPhase.during || RamadanPhase.lastTen || RamadanPhase.far => '',
    };
