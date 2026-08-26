import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/premium.dart';

abstract class PurchaseService {
  Stream<PremiumEntitlement> get entitlementUpdates;
  Future<List<StoreProduct>> loadProducts();
  Future<void> purchase(PurchaseProduct product);
  Future<void> restorePurchases();
  Future<bool> isStoreAvailable();
  Future<void> dispose();
}

class InAppPurchaseService implements PurchaseService {
  final InAppPurchase store;
  final StreamController<PremiumEntitlement> _updates =
      StreamController.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  InAppPurchaseService({InAppPurchase? store})
    : store = store ?? InAppPurchase.instance {
    _subscription = this.store.purchaseStream.listen(_handlePurchases);
  }
  @override
  Stream<PremiumEntitlement> get entitlementUpdates => _updates.stream;
  @override
  Future<bool> isStoreAvailable() => store.isAvailable();
  @override
  Future<List<StoreProduct>> loadProducts() async {
    final response = await store.queryProductDetails(
      PurchaseProduct.values.map((p) => p.id).toSet(),
    );
    return response.productDetails
        .map(
          (detail) => StoreProduct(
            product: PurchaseProduct.values.firstWhere(
              (p) => p.id == detail.id,
            ),
            id: detail.id,
            title: detail.title,
            description: detail.description,
            price: detail.price,
            rawPrice: detail.rawPrice,
          ),
        )
        .toList();
  }

  @override
  Future<void> purchase(PurchaseProduct product) async {
    final response = await store.queryProductDetails({product.id});
    if (response.productDetails.isEmpty) {
      throw StateError('Store product unavailable');
    }
    final param = PurchaseParam(productDetails: response.productDetails.single);
    await store.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> restorePurchases() => store.restorePurchases();
  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final product = PurchaseProduct.values
            .where((p) => p.id == purchase.productID)
            .firstOrNull;
        if (product != null) {
          _updates.add(
            PremiumEntitlement(
              status: product == PurchaseProduct.lifetime
                  ? EntitlementStatus.premiumLifetime
                  : EntitlementStatus.premiumSubscription,
              productId: purchase.productID,
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
      if (purchase.pendingCompletePurchase) {
        store.completePurchase(purchase);
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _updates.close();
  }
}
