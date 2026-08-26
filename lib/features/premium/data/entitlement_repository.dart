import '../../../core/storage/local_storage.dart';
import '../domain/premium.dart';

class EntitlementRepository {
  final LocalStorage storage;
  const EntitlementRepository(this.storage);
  static const key = 'dini.premium.entitlement.v1';
  Future<PremiumEntitlement> load() async {
    final value = await storage.read(key);
    if (value == 'lifetime') {
      return const PremiumEntitlement(
        status: EntitlementStatus.premiumLifetime,
      );
    }
    if (value == 'subscription') {
      return const PremiumEntitlement(
        status: EntitlementStatus.premiumSubscription,
      );
    }
    return const PremiumEntitlement();
  }

  Future<void> save(PremiumEntitlement value) =>
      storage.write(key, switch (value.status) {
        EntitlementStatus.free => 'free',
        EntitlementStatus.premiumSubscription => 'subscription',
        EntitlementStatus.premiumLifetime => 'lifetime',
      });
  Future<void> clearCache() => storage.remove(key);
}
