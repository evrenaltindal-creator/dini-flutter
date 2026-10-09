/// Namaz Yolu'nun kaynaklı, çevrimdışı temel bilgi kataloğu.
///
/// Metinler yerelleştirme anahtarlarıyla tutulur. Böylece Türkçe, İngilizce
/// ve Arapça içerik aynı konu yapısını paylaşır ve dil paritesi testle korunur.
class KnowledgeSection {
  final String id;
  final String titleKey;
  final String introKey;
  final List<KnowledgeArticle> articles;

  const KnowledgeSection({
    required this.id,
    required this.titleKey,
    required this.introKey,
    required this.articles,
  });
}

class KnowledgeArticle {
  final String id;
  final String titleKey;
  final String summaryKey;
  final String bodyKey;
  final String sourceName;
  final String sourceUrl;

  const KnowledgeArticle({
    required this.id,
    required this.titleKey,
    required this.summaryKey,
    required this.bodyKey,
    required this.sourceName,
    required this.sourceUrl,
  });
}

const islamicKnowledgeSections = <KnowledgeSection>[
  KnowledgeSection(
    id: 'prophets',
    titleKey: 'knowledge.prophets.title',
    introKey: 'knowledge.prophets.intro',
    articles: [
      KnowledgeArticle(
        id: 'mission',
        titleKey: 'knowledge.prophets.mission.title',
        summaryKey: 'knowledge.prophets.mission.summary',
        bodyKey: 'knowledge.prophets.mission.body',
        sourceName: 'TDV İslâm Ansiklopedisi — Peygamber',
        sourceUrl: 'https://islamansiklopedisi.org.tr/peygamber',
      ),
      KnowledgeArticle(
        id: 'ibrahim',
        titleKey: 'knowledge.prophets.ibrahim.title',
        summaryKey: 'knowledge.prophets.ibrahim.summary',
        bodyKey: 'knowledge.prophets.ibrahim.body',
        sourceName: 'TDV İslâm Ansiklopedisi — İbrâhim',
        sourceUrl: 'https://islamansiklopedisi.org.tr/ibrahim',
      ),
      KnowledgeArticle(
        id: 'musa',
        titleKey: 'knowledge.prophets.musa.title',
        summaryKey: 'knowledge.prophets.musa.summary',
        bodyKey: 'knowledge.prophets.musa.body',
        sourceName: 'TDV İslâm Ansiklopedisi — Mûsâ',
        sourceUrl: 'https://islamansiklopedisi.org.tr/musa',
      ),
      KnowledgeArticle(
        id: 'muhammad',
        titleKey: 'knowledge.prophets.muhammad.title',
        summaryKey: 'knowledge.prophets.muhammad.summary',
        bodyKey: 'knowledge.prophets.muhammad.body',
        sourceName: 'TDV İslâm Ansiklopedisi — Muhammed',
        sourceUrl: 'https://islamansiklopedisi.org.tr/muhammed',
      ),
    ],
  ),
  KnowledgeSection(
    id: 'religions',
    titleKey: 'knowledge.religions.title',
    introKey: 'knowledge.religions.intro',
    articles: [
      KnowledgeArticle(
        id: 'method',
        titleKey: 'knowledge.religions.method.title',
        summaryKey: 'knowledge.religions.method.summary',
        bodyKey: 'knowledge.religions.method.body',
        sourceName: 'TDV İslâm Ansiklopedisi — Dinler Tarihi',
        sourceUrl: 'https://islamansiklopedisi.org.tr/dinler-tarihi',
      ),
      KnowledgeArticle(
        id: 'judaism',
        titleKey: 'knowledge.religions.judaism.title',
        summaryKey: 'knowledge.religions.judaism.summary',
        bodyKey: 'knowledge.religions.judaism.body',
        sourceName: 'TDV İslâm Ansiklopedisi — Yahudilik',
        sourceUrl: 'https://islamansiklopedisi.org.tr/yahudilik',
      ),
      KnowledgeArticle(
        id: 'christianity',
        titleKey: 'knowledge.religions.christianity.title',
        summaryKey: 'knowledge.religions.christianity.summary',
        bodyKey: 'knowledge.religions.christianity.body',
        sourceName: 'TDV İslâm Ansiklopedisi — Hıristiyanlık',
        sourceUrl: 'https://islamansiklopedisi.org.tr/hiristiyanlik',
      ),
      KnowledgeArticle(
        id: 'islam',
        titleKey: 'knowledge.religions.islam.title',
        summaryKey: 'knowledge.religions.islam.summary',
        bodyKey: 'knowledge.religions.islam.body',
        sourceName: 'TDV İslâm Ansiklopedisi — İslâm',
        sourceUrl: 'https://islamansiklopedisi.org.tr/islam',
      ),
    ],
  ),
  KnowledgeSection(
    id: 'fiqh',
    titleKey: 'knowledge.fiqh.title',
    introKey: 'knowledge.fiqh.intro',
    articles: [
      KnowledgeArticle(
        id: 'foundations',
        titleKey: 'knowledge.fiqh.foundations.title',
        summaryKey: 'knowledge.fiqh.foundations.summary',
        bodyKey: 'knowledge.fiqh.foundations.body',
        sourceName: 'Diyanet İlmihal I — İman ve İbadetler',
        sourceUrl: 'https://webdosya.diyanet.gov.tr/diyanetanasayfa/userfiles/dinibilgiler/ilmihal_cilt_1.pdf',
      ),
      KnowledgeArticle(
        id: 'purification',
        titleKey: 'knowledge.fiqh.purification.title',
        summaryKey: 'knowledge.fiqh.purification.summary',
        bodyKey: 'knowledge.fiqh.purification.body',
        sourceName: 'Diyanet — İslam İlmihali',
        sourceUrl: 'https://dijital.diyanet.gov.tr/Kitaplik/ilmihal-fikih/islam-ilmihali?id=392',
      ),
      KnowledgeArticle(
        id: 'worship',
        titleKey: 'knowledge.fiqh.worship.title',
        summaryKey: 'knowledge.fiqh.worship.summary',
        bodyKey: 'knowledge.fiqh.worship.body',
        sourceName: 'Diyanet — İbadetim',
        sourceUrl: 'https://dijital.diyanet.gov.tr/Kitaplik/ilmihal-fikih/ibadetim?id=4132',
      ),
      KnowledgeArticle(
        id: 'schools',
        titleKey: 'knowledge.fiqh.schools.title',
        summaryKey: 'knowledge.fiqh.schools.summary',
        bodyKey: 'knowledge.fiqh.schools.body',
        sourceName: 'Diyanet — Temel Dinî Bilgiler',
        sourceUrl: 'https://dijital.diyanet.gov.tr/Kitaplik/ilmihal-fikih/temel-dini-bilgiler?id=4218',
      ),
    ],
  ),
];

KnowledgeSection? knowledgeSectionById(String? id) {
  for (final section in islamicKnowledgeSections) {
    if (section.id == id) return section;
  }
  return null;
}

KnowledgeArticle? knowledgeArticleById(KnowledgeSection section, String? id) {
  for (final article in section.articles) {
    if (article.id == id) return article;
  }
  return null;
}
