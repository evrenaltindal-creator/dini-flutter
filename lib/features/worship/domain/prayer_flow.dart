import 'worship_guide.dart';

/// Namaz sırasında okunan bir metnin ekranda gösterilen karşılığı.
///
/// Arapça metin ve okunuş dile göre değişmez, bu yüzden düz metin tutulur.
/// Ad, anlam ve kaynak künyesi kullanıcıya görünen metinlerdir; üç dilde
/// karşılığı olsun diye `AppLocalizations` anahtarı olarak tutulur.
class Recitation {
  /// Ekranda görünecek adın yerelleştirme anahtarı.
  final String nameKey;

  /// Arap harfleriyle metin.
  final String arabic;

  /// Latin harfleriyle okunuş (Türkçe yazım).
  final String transliteration;

  /// Anlamın yerelleştirme anahtarı.
  final String meaningKey;

  /// Kaynak künyesinin yerelleştirme anahtarı. İçerik girilmişse zorunludur.
  final String sourceKey;

  const Recitation({
    this.nameKey = '',
    this.arabic = '',
    this.transliteration = '',
    this.meaningKey = '',
    this.sourceKey = '',
  });

  /// Gösterilecek hiçbir metin yoksa true.
  bool get isEmpty =>
      arabic.isEmpty && transliteration.isEmpty && meaningKey.isEmpty;

  /// Arapça metin, okunuş, anlam ve kaynağın tamamı girilmişse true.
  bool get isComplete =>
      arabic.isNotEmpty &&
      transliteration.isNotEmpty &&
      meaningKey.isNotEmpty &&
      sourceKey.isNotEmpty;

  /// İçerik var ama kaynağı belirtilmemiş: yayına çıkmadan yakalanmalı.
  bool get isMissingSource => !isEmpty && sourceKey.isEmpty;

  /// Bazı alanlar dolu, bazıları boş: yarım kalmış giriş.
  bool get isPartial => !isEmpty && !isComplete;
}

/// Namazda okunan metinlerin listesi. Bunlar Diyanet'in "Namaz Duaları"
/// yayınlarında geçen yaygın adlardır; burada yalnızca hangi metinlerin
/// doldurulacağını belirten bir dizindir, dinî bir hüküm içermez.
enum RecitationId {
  subhaneke,
  fatiha,
  ettehiyyatu,
  allahummeSalli,
  allahummeBarik,
  rabbenaAtina,
  rabbenagfirli,
  kunut,
}

/// Bir rekâtın akışı. [movementKeys], zaten üç dilde hazır olan
/// `guide.prayerStepN` yerelleştirme anahtarlarını taşır; bu sınıf yeni bir
/// dinî anlatım eklemez, mevcut adımları rekâtlara dağıtır.
class RakatFlow {
  final int index;
  final List<String> movementKeys;

  const RakatFlow({required this.index, required this.movementKeys});
}

/// Bir namaz bölümünün (ilk sünnet, farz, son sünnet, vitir) rekât rekât akışı.
class PrayerPartFlow {
  final PrayerPartKind kind;
  final List<RakatFlow> rakats;

  const PrayerPartFlow({required this.kind, required this.rakats});
}

/// İlk rekât başlangıç tekbiriyle açılır; sonraki rekâtlar aynı gövdeyi
/// tekrarlar. Son oturuş, rekâtların ardından ayrı bir adım olarak gösterilir.
const _openingKey = 'guide.prayerStep1';
const _bodyKeys = [
  'guide.prayerStep2',
  'guide.prayerStep3',
  'guide.prayerStep4',
  'guide.prayerStep5',
  'guide.prayerStep6',
  'guide.prayerStep7',
];
const finalSittingKey = 'guide.prayerStep8';

/// [rakats] adet rekâtı sıraya dizer.
List<RakatFlow> rakatFlow(int rakats) => [
  for (var index = 1; index <= rakats; index++)
    RakatFlow(
      index: index,
      movementKeys: index == 1 ? [_openingKey, ..._bodyKeys] : _bodyKeys,
    ),
];

/// Bir namazın tüm bölümlerini rekât rekât açar.
List<PrayerPartFlow> prayerFlow(DailyPrayerGuide guide) => [
  for (final part in guide.parts)
    PrayerPartFlow(kind: part.kind, rakats: rakatFlow(part.rakats)),
];

/// Okunacak metinlerin kütüphanesi.
///
/// Arapça metin ve okunuş burada durur; ad, anlam ve kaynak künyesi üç dilde
/// `app_localizations.dart` içindedir.
///
/// Kaynaklar: Kur’an’dan alınan metinlerde sûre ve âyet numarası verilir;
/// namaz duaları için Diyanet İşleri Başkanlığı’nın namaz ilmihali esas
/// alınmıştır. `recitation_content_test.dart` kaynaksız veya yarım kalmış
/// bir kaydın yayına çıkmasını engeller.
const recitationLibrary = <RecitationId, Recitation>{
  RecitationId.subhaneke: Recitation(
    nameKey: 'recitation.subhaneke.name',
    arabic:
        'سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ وَتَبَارَكَ اسْمُكَ '
        'وَتَعَالَى جَدُّكَ وَلَا إِلَهَ غَيْرُكَ',
    transliteration:
        'Sübhâneke’llâhümme ve bi-hamdik. Ve tebârake’smük. '
        'Ve teâlâ ceddük. Ve lâ ilâhe ğayruk.',
    meaningKey: 'recitation.subhaneke.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.fatiha: Recitation(
    nameKey: 'recitation.fatiha.name',
    arabic:
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n'
        'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ\n'
        'الرَّحْمَٰنِ الرَّحِيمِ\n'
        'مَالِكِ يَوْمِ الدِّينِ\n'
        'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ\n'
        'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ\n'
        'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ '
        'عَلَيْهِمْ وَلَا الضَّالِّينَ',
    transliteration:
        'Bismillâhirrahmânirrahîm. Elhamdü lillâhi rabbi’l-âlemîn. '
        'Errahmâni’r-rahîm. Mâliki yevmi’d-dîn. İyyâke na’büdü ve iyyâke '
        'nesta’în. İhdine’s-sırâta’l-müstakîm. Sırâta’llezîne en’amte '
        'aleyhim, ğayri’l-mağdûbi aleyhim ve le’d-dâllîn.',
    meaningKey: 'recitation.fatiha.meaning',
    sourceKey: 'recitation.source.fatiha',
  ),
  RecitationId.ettehiyyatu: Recitation(
    nameKey: 'recitation.ettehiyyatu.name',
    arabic:
        'التَّحِيَّاتُ لِلَّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، '
        'السَّلَامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللَّهِ '
        'وَبَرَكَاتُهُ، السَّلَامُ عَلَيْنَا وَعَلَى عِبَادِ اللَّهِ '
        'الصَّالِحِينَ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ '
        'وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ',
    transliteration:
        'Ettehiyyâtü lillâhi ve’s-salavâtü ve’t-tayyibât. Esselâmü aleyke '
        'eyyühe’n-nebiyyü ve rahmetullâhi ve berakâtüh. Esselâmü aleynâ ve '
        'alâ ibâdillâhi’s-sâlihîn. Eşhedü en lâ ilâhe illallâh ve eşhedü '
        'enne Muhammeden abdühû ve rasûlüh.',
    meaningKey: 'recitation.ettehiyyatu.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.allahummeSalli: Recitation(
    nameKey: 'recitation.allahummeSalli.name',
    arabic:
        'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، '
        'كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، '
        'إِنَّكَ حَمِيدٌ مَجِيدٌ',
    transliteration:
        'Allâhümme salli alâ Muhammedin ve alâ âli Muhammed. Kemâ salleyte '
        'alâ İbrâhîme ve alâ âli İbrâhîm. İnneke hamîdün mecîd.',
    meaningKey: 'recitation.allahummeSalli.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.allahummeBarik: Recitation(
    nameKey: 'recitation.allahummeBarik.name',
    arabic:
        'اللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، '
        'كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، '
        'إِنَّكَ حَمِيدٌ مَجِيدٌ',
    transliteration:
        'Allâhümme bârik alâ Muhammedin ve alâ âli Muhammed. Kemâ bârekte '
        'alâ İbrâhîme ve alâ âli İbrâhîm. İnneke hamîdün mecîd.',
    meaningKey: 'recitation.allahummeBarik.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.rabbenaAtina: Recitation(
    nameKey: 'recitation.rabbenaAtina.name',
    arabic:
        'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً '
        'وَقِنَا عَذَابَ النَّارِ',
    transliteration:
        'Rabbenâ âtinâ fi’d-dünyâ haseneten ve fi’l-âhirati haseneten ve '
        'kınâ azâbe’n-nâr.',
    meaningKey: 'recitation.rabbenaAtina.meaning',
    sourceKey: 'recitation.source.bakara201',
  ),
  RecitationId.rabbenagfirli: Recitation(
    nameKey: 'recitation.rabbenagfirli.name',
    arabic:
        'رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ '
        'يَقُومُ الْحِسَابُ',
    transliteration:
        'Rabbenâğfirlî ve li-vâlideyye ve lil-mü’minîne yevme '
        'yekûmü’l-hisâb.',
    meaningKey: 'recitation.rabbenagfirli.meaning',
    sourceKey: 'recitation.source.ibrahim41',
  ),
  RecitationId.kunut: Recitation(
    nameKey: 'recitation.kunut.name',
    arabic:
        'اللَّهُمَّ إِنَّا نَسْتَعِينُكَ وَنَسْتَغْفِرُكَ وَنَسْتَهْدِيكَ '
        'وَنُؤْمِنُ بِكَ وَنَتُوبُ إِلَيْكَ وَنَتَوَكَّلُ عَلَيْكَ '
        'وَنُثْنِي عَلَيْكَ الْخَيْرَ كُلَّهُ نَشْكُرُكَ وَلَا نَكْفُرُكَ '
        'وَنَخْلَعُ وَنَتْرُكُ مَنْ يَفْجُرُكَ\n'
        'اللَّهُمَّ إِيَّاكَ نَعْبُدُ وَلَكَ نُصَلِّي وَنَسْجُدُ '
        'وَإِلَيْكَ نَسْعَى وَنَحْفِدُ نَرْجُو رَحْمَتَكَ وَنَخْشَى '
        'عَذَابَكَ إِنَّ عَذَابَكَ بِالْكُفَّارِ مُلْحِقٌ',
    transliteration:
        'Allâhümme innâ nesteînüke ve nestağfirüke ve nestehdîk. Ve nü’minü '
        'bike ve netûbü ileyk. Ve netevekkelü aleyke ve nüsnî aleyke’l-hayra '
        'küllehû neşkürüke ve lâ nekfürüke ve nahleu ve netrükü men '
        'yefcürük.\n'
        'Allâhümme iyyâke na’büdü ve leke nusallî ve nescüd. Ve ileyke nes’â '
        've nahfid. Nercû rahmeteke ve nahşâ azâbek. İnne azâbeke '
        'bi’l-küffâri mülhık.',
    meaningKey: 'recitation.kunut.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
};
