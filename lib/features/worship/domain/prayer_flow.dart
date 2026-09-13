import 'worship_guide.dart';

/// Namaz sırasında okunan bir metnin üç parçalı karşılığı.
///
/// ÖNEMLİ: Bu depo dinî metin ÜRETMEZ. [arabic], [transliteration] ve
/// [meaning] alanları güvenilir bir kaynaktan (ör. Diyanet yayınları) elle
/// doldurulur; [source] hangi kaynaktan alındığını uygulamada gösterir.
/// Alanlar boş bırakıldığı sürece arayüz "henüz eklenmedi" notu gösterir,
/// tahmini bir metin göstermez.
class Recitation {
  /// Ekranda görünecek ad (ör. okunan sûrenin veya duanın adı).
  final String name;
  final String arabic;

  /// Türkçe okunuş.
  final String transliteration;
  final String meaning;

  /// Metnin alındığı kaynak. İçerik eklendiğinde doldurulması zorunludur.
  final String source;

  const Recitation({
    this.name = '',
    this.arabic = '',
    this.transliteration = '',
    this.meaning = '',
    this.source = '',
  });

  /// Gösterilecek hiçbir metin yoksa true.
  bool get isEmpty =>
      arabic.isEmpty && transliteration.isEmpty && meaning.isEmpty;

  /// Arapça metin, okunuş, anlam ve kaynağın tamamı girilmişse true.
  bool get isComplete =>
      arabic.isNotEmpty &&
      transliteration.isNotEmpty &&
      meaning.isNotEmpty &&
      source.isNotEmpty;

  /// İçerik var ama kaynağı belirtilmemiş: yayına çıkmadan yakalanmalı.
  bool get isMissingSource => !isEmpty && source.isEmpty;

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
/// Yapı hazırdır, METİNLER BİLİNÇLİ OLARAK BOŞTUR. Her kayda Diyanet'in
/// ilgili yayınından Arapça metin, okunuş, anlam ve kaynak künyesi ELLE
/// eklenecektir. Buraya ezberden veya tahminle metin yazılmamalıdır:
/// dinî metinde tek harflik bir sapma ciddi bir kusurdur.
///
/// Bir kaydı doldurmak için o satırdaki boş alanları doldurun, örneğin:
///
/// ```dart
/// RecitationId.subhaneke: Recitation(
///   name: 'Sübhâneke',
///   arabic: '…',
///   transliteration: '…',
///   meaning: '…',
///   source: 'Diyanet İşleri Başkanlığı, Namaz Duaları',
/// ),
/// ```
///
/// `recitation_content_test.dart` şunları zorunlu kılar: kaynaksız metin
/// olamaz, Arapça alan gerçekten Arap harfleri içermelidir ve bir kayıt ya
/// tamamen boş ya da tam olmalıdır (yarım metin yayına çıkamaz).
const recitationLibrary = <RecitationId, Recitation>{
  RecitationId.subhaneke: Recitation(name: 'Sübhâneke'),
  RecitationId.fatiha: Recitation(name: 'Fâtiha sûresi'),
  RecitationId.ettehiyyatu: Recitation(name: 'Ettehiyyâtü'),
  RecitationId.allahummeSalli: Recitation(name: 'Allâhümme salli'),
  RecitationId.allahummeBarik: Recitation(name: 'Allâhümme bârik'),
  RecitationId.rabbenaAtina: Recitation(name: 'Rabbenâ âtinâ'),
  RecitationId.rabbenagfirli: Recitation(name: 'Rabbenâğfirlî'),
  RecitationId.kunut: Recitation(name: 'Kunut duaları'),
};
