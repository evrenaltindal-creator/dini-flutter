import 'package:flutter_test/flutter_test.dart';

import 'package:dini_flutter/core/storage/storage_provider.dart';
import 'package:dini_flutter/features/premium/data/entitlement_repository.dart';
import 'package:dini_flutter/features/premium/domain/premium.dart';

void main() {
  test('all core religious features remain free', () {
    const policy = FreeFeaturePolicy();
    for (final feature in [
      'prayer_times',
      'qibla',
      'notifications',
      'hijri_calendar',
      'religious_events',
      'daily_content',
      'prayer_tracker',
      'tasbih',
      'basic_widget',
      'default_mosque_theme',
    ]) {
      expect(policy.isFree(feature), isTrue);
    }
  });

  test('product mapping is centralized and lifetime is non-consumable', () {
    expect(PurchaseProduct.monthly.id, contains('.monthly.'));
    expect(PurchaseProduct.yearly.id, contains('.yearly.'));
    expect(PurchaseProduct.lifetime.id, contains('.lifetime.'));
    expect(PurchaseProduct.monthly.isSubscription, isTrue);
    expect(PurchaseProduct.yearly.isSubscription, isTrue);
    expect(PurchaseProduct.lifetime.isSubscription, isFalse);
  });

  test(
    'premium entitlement cache round trips and can be cleared locally',
    () async {
      final repository = EntitlementRepository(MemoryStorage());
      await repository.save(
        const PremiumEntitlement(status: EntitlementStatus.premiumLifetime),
      );
      expect(
        (await repository.load()).status,
        EntitlementStatus.premiumLifetime,
      );
      await repository.clearCache();
      expect((await repository.load()).status, EntitlementStatus.free);
    },
  );

  test('premium themes are gated while the default theme remains free', () {
    const policy = PremiumThemePolicy();
    const free = PremiumEntitlement();
    const lifetime = PremiumEntitlement(
      status: EntitlementStatus.premiumLifetime,
    );
    expect(policy.isAvailable(PremiumTheme.defaultMosque, free), isTrue);
    expect(policy.isAvailable(PremiumTheme.dawnGarden, free), isFalse);
    expect(policy.isAvailable(PremiumTheme.dawnGarden, lifetime), isTrue);
  });

  test('free entitlement never requires a store product or invented price', () {
    const free = PremiumEntitlement();
    expect(free.isPremium, isFalse);
    expect(StoreProductIds.monthly, endsWith('.dev'));
  });

  test(
    'delete-all local cache does not imply store ownership cancellation',
    () async {
      final repository = EntitlementRepository(MemoryStorage());
      await repository.save(
        const PremiumEntitlement(status: EntitlementStatus.premiumSubscription),
      );
      await repository.clearCache();
      expect((await repository.load()).isPremium, isFalse);
      // Store ownership is external and is intentionally untouched by this repository.
    },
  );
}
