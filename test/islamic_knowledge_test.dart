import 'package:dini_flutter/core/localization/app_localizations.dart';
import 'package:dini_flutter/features/knowledge/domain/islamic_knowledge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog contains prophets, religions and fiqh sections', () {
    expect(islamicKnowledgeSections.map((section) => section.id), [
      'prophets',
      'religions',
      'fiqh',
    ]);
    expect(
      islamicKnowledgeSections.every((section) => section.articles.length >= 4),
      isTrue,
    );
  });

  test('section and article addresses are unique and resolvable', () {
    final sectionIds = islamicKnowledgeSections
        .map((section) => section.id)
        .toSet();
    expect(sectionIds, hasLength(islamicKnowledgeSections.length));

    for (final section in islamicKnowledgeSections) {
      expect(knowledgeSectionById(section.id), same(section));
      final articleIds = section.articles.map((article) => article.id).toSet();
      expect(articleIds, hasLength(section.articles.length));
      for (final article in section.articles) {
        expect(knowledgeArticleById(section, article.id), same(article));
        expect(Uri.parse(article.sourceUrl).isScheme('https'), isTrue);
      }
    }
    expect(knowledgeSectionById('unknown'), isNull);
  });

  test('all catalog copy exists in Turkish, English and Arabic', () {
    for (final language in ['tr', 'en', 'ar']) {
      final l10n = AppLocalizations(Locale(language));
      for (final section in islamicKnowledgeSections) {
        for (final key in [section.titleKey, section.introKey]) {
          expect(l10n.text(key), isNot(key), reason: '$language: $key');
        }
        for (final article in section.articles) {
          for (final key in [
            article.titleKey,
            article.summaryKey,
            article.bodyKey,
          ]) {
            expect(l10n.text(key), isNot(key), reason: '$language: $key');
          }
        }
      }
    }
  });
}
