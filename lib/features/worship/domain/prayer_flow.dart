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

  // Namaz hocasının adım adım okuttuğu kısa metinler.
  tekbir,
  euzuBesmele,
  besmele,
  rukuTesbih,
  semiallahu,
  rabbenaLekelHamd,
  secdeTesbih,
  selam,

  // Zamm-ı sûre: Fâtiha'dan sonra okunan kısa sûreler. Rekâtlarda Mushaf
  // sırasıyla (Kevser, İhlâs, Felak, Nâs) okunur; ters sırayla okumak
  // mekruhtur.
  kevser,
  ihlas,
  felak,
  nas,
}

/// Namaz rehberi sayfasında "Okunacak metinler" başlığı altında gösterilen
/// uzun metinler. Tekbir ve tesbih gibi kısa metinler yalnızca namaz
/// hocasında, yerinde gösterilir.
const guideRecitationIds = [
  RecitationId.subhaneke,
  RecitationId.fatiha,
  RecitationId.ettehiyyatu,
  RecitationId.allahummeSalli,
  RecitationId.allahummeBarik,
  RecitationId.rabbenaAtina,
  RecitationId.rabbenagfirli,
  RecitationId.kunut,
];

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
  RecitationId.tekbir: Recitation(
    nameKey: 'recitation.tekbir.name',
    arabic: 'اللَّهُ أَكْبَرُ',
    transliteration: 'Allâhü ekber.',
    meaningKey: 'recitation.tekbir.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.euzuBesmele: Recitation(
    nameKey: 'recitation.euzuBesmele.name',
    arabic:
        'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\n'
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
    transliteration:
        'Eûzü billâhi mine’ş-şeytâni’r-racîm. Bismillâhirrahmânirrahîm.',
    meaningKey: 'recitation.euzuBesmele.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.besmele: Recitation(
    nameKey: 'recitation.besmele.name',
    arabic: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
    transliteration: 'Bismillâhirrahmânirrahîm.',
    meaningKey: 'recitation.besmele.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.rukuTesbih: Recitation(
    nameKey: 'recitation.rukuTesbih.name',
    arabic: 'سُبْحَانَ رَبِّيَ الْعَظِيمِ',
    transliteration: 'Sübhâne rabbiye’l-azîm.',
    meaningKey: 'recitation.rukuTesbih.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.semiallahu: Recitation(
    nameKey: 'recitation.semiallahu.name',
    arabic: 'سَمِعَ اللَّهُ لِمَنْ حَمِدَهُ',
    transliteration: 'Semiallâhü limen hamideh.',
    meaningKey: 'recitation.semiallahu.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.rabbenaLekelHamd: Recitation(
    nameKey: 'recitation.rabbenaLekelHamd.name',
    arabic: 'رَبَّنَا لَكَ الْحَمْدُ',
    transliteration: 'Rabbenâ leke’l-hamd.',
    meaningKey: 'recitation.rabbenaLekelHamd.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.secdeTesbih: Recitation(
    nameKey: 'recitation.secdeTesbih.name',
    arabic: 'سُبْحَانَ رَبِّيَ الْأَعْلَى',
    transliteration: 'Sübhâne rabbiye’l-a’lâ.',
    meaningKey: 'recitation.secdeTesbih.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.selam: Recitation(
    nameKey: 'recitation.selam.name',
    arabic: 'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ',
    transliteration: 'Esselâmü aleyküm ve rahmetullâh.',
    meaningKey: 'recitation.selam.meaning',
    sourceKey: 'recitation.source.ilmihal',
  ),
  RecitationId.kevser: Recitation(
    nameKey: 'recitation.kevser.name',
    arabic:
        'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ\n'
        'فَصَلِّ لِرَبِّكَ وَانْحَرْ\n'
        'إِنَّ شَانِئَكَ هُوَ الْأَبْتَرُ',
    transliteration:
        'İnnâ a’taynâke’l-kevser. Fe salli li-rabbike venhar. '
        'İnne şânieke hüve’l-ebter.',
    meaningKey: 'recitation.kevser.meaning',
    sourceKey: 'recitation.source.kevser',
  ),
  RecitationId.ihlas: Recitation(
    nameKey: 'recitation.ihlas.name',
    arabic:
        'قُلْ هُوَ اللَّهُ أَحَدٌ\n'
        'اللَّهُ الصَّمَدُ\n'
        'لَمْ يَلِدْ وَلَمْ يُولَدْ\n'
        'وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ',
    transliteration:
        'Kul hüvallâhü ehad. Allâhü’s-samed. Lem yelid ve lem yûled. '
        'Ve lem yekün lehû küfüven ehad.',
    meaningKey: 'recitation.ihlas.meaning',
    sourceKey: 'recitation.source.ihlas',
  ),
  RecitationId.felak: Recitation(
    nameKey: 'recitation.felak.name',
    arabic:
        'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ\n'
        'مِنْ شَرِّ مَا خَلَقَ\n'
        'وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ\n'
        'وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ\n'
        'وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ',
    transliteration:
        'Kul eûzü bi-rabbi’l-felak. Min şerri mâ halak. Ve min şerri '
        'ğâsikın izâ vekab. Ve min şerri’n-neffâsâti fi’l-ukad. Ve min '
        'şerri hâsidin izâ hased.',
    meaningKey: 'recitation.felak.meaning',
    sourceKey: 'recitation.source.felak',
  ),
  RecitationId.nas: Recitation(
    nameKey: 'recitation.nas.name',
    arabic:
        'قُلْ أَعُوذُ بِرَبِّ النَّاسِ\n'
        'مَلِكِ النَّاسِ\n'
        'إِلَٰهِ النَّاسِ\n'
        'مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ\n'
        'الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ\n'
        'مِنَ الْجِنَّةِ وَالنَّاسِ',
    transliteration:
        'Kul eûzü bi-rabbi’n-nâs. Meliki’n-nâs. İlâhi’n-nâs. Min '
        'şerri’l-vesvâsi’l-hannâs. Ellezî yüvesvisü fî sudûri’n-nâs. '
        'Mine’l-cinneti ve’n-nâs.',
    meaningKey: 'recitation.nas.meaning',
    sourceKey: 'recitation.source.nas',
  ),
};
