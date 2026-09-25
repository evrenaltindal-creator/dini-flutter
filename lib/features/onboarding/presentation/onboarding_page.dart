import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/storage_provider.dart';
import '../../home/presentation/mosque_backdrop.dart';
import '../../notifications/data/notification_scheduler.dart';
import '../data/onboarding_repository.dart';
import '../data/system_settings.dart';
import '../domain/onboarding.dart';

/// İlk açılış akışı: dil → konum → bildirim izni → pil rehberi.
///
/// Uygulama bu akış yazılana kadar doğrudan ana ekrana düşüyordu; dil, konum
/// ve bildirim izni hiç sorulmuyordu. Bildirim izni özellikle önemli: hiç
/// istenmezse alarmlar kurulur ama görünmez.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  OnboardingStep step = onboardingSteps.first;

  Future<void> _finish() async {
    await OnboardingRepository(ref.read(localStorageProvider)).markCompleted();
    if (!mounted) return;
    context.go('/');
  }

  void _advance() {
    final next = nextOnboardingStep(step);
    if (next == null) {
      _finish();
      return;
    }
    setState(() => step = next);
  }

  Future<void> _runAction() async {
    switch (step) {
      case OnboardingStep.language:
        break;
      case OnboardingStep.location:
        // Konum ekranı akışın üstüne açılır; dönüşte akış kaldığı yerden
        // devam eder.
        await context.push('/location');
      case OnboardingStep.notifications:
        await ref.read(notificationServiceProvider).requestPermission();
      case OnboardingStep.battery:
        final opened = await ref.read(systemSettingsProvider).openAppSettings();
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.text('onboarding.battery.unavailable'),
              ),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final index = onboardingSteps.indexOf(step);

    return MosqueBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StepDots(
                        count: onboardingSteps.length,
                        current: index,
                      ),
                    ),
                    TextButton(
                      onPressed: _finish,
                      child: Text(l10n.text('onboarding.skip')),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.text(onboardingKey(step, 'title')),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.text(onboardingKey(step, 'body')),
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (step == OnboardingStep.language)
                          _LanguageChoice(onSelected: _setLanguage)
                        else
                          FilledButton.tonalIcon(
                            onPressed: _runAction,
                            icon: Icon(_actionIcon),
                            label: Text(
                              l10n.text(onboardingKey(step, 'action')),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _advance,
                  child: Text(
                    l10n.text(
                      isLastOnboardingStep(step)
                          ? 'onboarding.finish'
                          : 'onboarding.next',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get _actionIcon => switch (step) {
    OnboardingStep.location => Icons.place_outlined,
    OnboardingStep.notifications => Icons.notifications_outlined,
    OnboardingStep.battery => Icons.battery_saver_outlined,
    OnboardingStep.language => Icons.language,
  };

  Future<void> _setLanguage(String languageCode) async {
    await ref
        .read(localStorageProvider)
        .write(localePreferenceKey, languageCode);
    ref.read(onboardingLocaleProvider.notifier).state = Locale(languageCode);
  }
}

/// Akış sırasında seçilen dil. `main.dart` bunu `localeProvider` ile
/// eşleştirir; dil seçimi anında uygulanmalı ki sonraki adımlar yeni dilde
/// okunsun.
final onboardingLocaleProvider = StateProvider<Locale?>((ref) => null);

class _LanguageChoice extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _LanguageChoice({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final current = Localizations.localeOf(context).languageCode;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in const {
          'tr': 'Türkçe',
          'en': 'English',
          'ar': 'العربية',
        }.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: current == entry.key,
            onSelected: (_) => onSelected(entry.key),
          ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  final int count, current;

  const _StepDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < count; index++)
        Container(
          width: index == current ? 20 : 8,
          height: 8,
          margin: const EdgeInsetsDirectional.only(end: 6),
          decoration: BoxDecoration(
            color: index <= current ? Colors.white : const Color(0x55FFFFFF),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
    ],
  );
}
