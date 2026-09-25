/// İlk açılış akışının adımları.
///
/// Sıra rastgele değil: her adım bir öncekine dayanır. Dil seçilmeden
/// diğer ekranların metni anlaşılmaz; konum bilinmeden bildirimin hangi
/// vakitleri haber vereceği belirsiz; bildirim izni verilmeden pil rehberini
/// göstermenin anlamı yok.
enum OnboardingStep {
  /// Uygulama dili.
  language,

  /// Konum — vakitlerin doğruluğu buna bağlı.
  location,

  /// Bildirim izni.
  notifications,

  /// Pil optimizasyonu ve otomatik başlatma rehberi.
  battery,
}

/// Akıştaki adımların sırası.
const onboardingSteps = OnboardingStep.values;

/// [step] akışın son adımı mı?
bool isLastOnboardingStep(OnboardingStep step) => step == onboardingSteps.last;

/// [step] sonrası gelen adım; son adımsa null.
OnboardingStep? nextOnboardingStep(OnboardingStep step) {
  final index = onboardingSteps.indexOf(step);
  return index < 0 || index + 1 >= onboardingSteps.length
      ? null
      : onboardingSteps[index + 1];
}

/// Bir adımın metin anahtarlarının öneki.
String onboardingKey(OnboardingStep step, String suffix) =>
    'onboarding.${step.name}.$suffix';
