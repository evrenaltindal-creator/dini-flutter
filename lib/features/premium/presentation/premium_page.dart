import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/storage_provider.dart';
import '../data/entitlement_repository.dart';
import '../data/purchase_service.dart';
import '../domain/premium.dart';

class PremiumStorePage extends ConsumerStatefulWidget {
  const PremiumStorePage({super.key});

  @override
  ConsumerState<PremiumStorePage> createState() => _PremiumStorePageState();
}

class _PremiumStorePageState extends ConsumerState<PremiumStorePage> {
  late final InAppPurchaseService service;
  late final EntitlementRepository cache;
  Future<List<StoreProduct>>? products;
  PremiumEntitlement entitlement = const PremiumEntitlement();

  @override
  void initState() {
    super.initState();
    service = InAppPurchaseService();
    cache = EntitlementRepository(ref.read(localStorageProvider));
    products = _load();
    service.entitlementUpdates.listen((value) {
      if (!mounted) return;
      setState(() => entitlement = value);
      cache.save(value);
    });
  }

  Future<List<StoreProduct>> _load() async {
    final cached = await cache.load();
    if (mounted) setState(() => entitlement = cached);
    if (!await service.isStoreAvailable()) return [];
    return service.loadProducts();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${context.l10n.text('appTitle')} Premium')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.l10n.text('premium.freeTitle'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(context.l10n.text('premium.freeFeatures')),
          const SizedBox(height: 12),
          Text(context.l10n.text('premium.features')),
          const SizedBox(height: 20),
          FutureBuilder<List<StoreProduct>>(
            future: products,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Card(
                  child: ListTile(
                    title: Text(context.l10n.text('premium.loading')),
                  ),
                );
              }
              final values = snapshot.data ?? [];
              if (values.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(context.l10n.text('premium.unavailable')),
                  ),
                );
              }
              return Column(
                children: values
                    .map(
                      (value) => Card(
                        child: ListTile(
                          title: Text(value.title),
                          subtitle: Text(value.description),
                          trailing: TextButton(
                            onPressed: () async {
                              await service.purchase(value.product);
                            },
                            child: Text(value.price),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              await service.restorePurchases();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.text('premium.restoreSent')),
                ),
              );
            },
            child: Text(context.l10n.text('premium.restore')),
          ),
          if (entitlement.isPremium)
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: Text(context.l10n.text('premium.active')),
              subtitle: Text(context.l10n.text('premium.cache')),
            ),
        ],
      ),
    );
  }
}
