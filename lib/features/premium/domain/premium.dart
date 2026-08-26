enum EntitlementStatus { free, premiumSubscription, premiumLifetime }

enum PurchaseProduct { monthly, yearly, lifetime }

extension PurchaseProductX on PurchaseProduct {
  String get id => switch (this) {
    PurchaseProduct.monthly => StoreProductIds.monthly,
    PurchaseProduct.yearly => StoreProductIds.yearly,
    PurchaseProduct.lifetime => StoreProductIds.lifetime,
  };
  bool get isSubscription => this != PurchaseProduct.lifetime;
}

class StoreProductIds {
  static const monthly = String.fromEnvironment(
    'DINI_IOS_MONTHLY_PRODUCT_ID',
    defaultValue: 'com.dini.dini_flutter.premium.monthly.dev',
  );
  static const yearly = String.fromEnvironment(
    'DINI_IOS_YEARLY_PRODUCT_ID',
    defaultValue: 'com.dini.dini_flutter.premium.yearly.dev',
  );
  static const lifetime = String.fromEnvironment(
    'DINI_IOS_LIFETIME_PRODUCT_ID',
    defaultValue: 'com.dini.dini_flutter.premium.lifetime.dev',
  );

  static bool get usesDevelopmentPlaceholders =>
      monthly.endsWith('.dev') ||
      yearly.endsWith('.dev') ||
      lifetime.endsWith('.dev');

  const StoreProductIds._();
}

class PremiumEntitlement {
  final EntitlementStatus status;
  final String? productId;
  final DateTime? updatedAt;
  const PremiumEntitlement({
    this.status = EntitlementStatus.free,
    this.productId,
    this.updatedAt,
  });
  bool get isPremium => status != EntitlementStatus.free;
  PremiumEntitlement copyWith({
    EntitlementStatus? status,
    String? productId,
    DateTime? updatedAt,
  }) => PremiumEntitlement(
    status: status ?? this.status,
    productId: productId ?? this.productId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class StoreProduct {
  final PurchaseProduct product;
  final String id, title, description, price;
  final num rawPrice;
  const StoreProduct({
    required this.product,
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rawPrice,
  });
}

enum PremiumTheme { defaultMosque, dawnGarden, desertNight, ramadanLanterns }

class PremiumThemePolicy {
  const PremiumThemePolicy();
  bool isAvailable(PremiumTheme theme, PremiumEntitlement entitlement) =>
      theme == PremiumTheme.defaultMosque || entitlement.isPremium;
}

class FreeFeaturePolicy {
  const FreeFeaturePolicy();
  bool isFree(String feature) => const {
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
  }.contains(feature);
}
