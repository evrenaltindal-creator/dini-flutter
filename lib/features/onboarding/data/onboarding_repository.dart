import '../../../core/storage/local_storage.dart';

/// İlk açılış akışının tamamlanıp tamamlanmadığını saklar.
class OnboardingRepository {
  static const key = 'dini.onboarding.completed.v1';

  final LocalStorage storage;

  const OnboardingRepository(this.storage);

  Future<bool> isCompleted() async => await storage.read(key) == '1';

  Future<void> markCompleted() async => storage.write(key, '1');

  /// Yalnızca testler ve "sıfırla" için.
  Future<void> reset() async => storage.remove(key);
}
