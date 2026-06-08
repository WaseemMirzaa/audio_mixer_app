import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../domain/repositories/subscription_repository.dart';

/// RevenueCat is source of truth; configure keys via `Purchases.configure` in bootstrap.
class FirebaseSubscriptionRepository implements SubscriptionRepository {
  FirebaseSubscriptionRepository({this.entitlementId = 'pro'}) {
    Purchases.addCustomerInfoUpdateListener(_push);
  }

  final String entitlementId;
  final _ctrl = StreamController<SubscriptionSnapshot>.broadcast(sync: true);

  SubscriptionSnapshot _fromCustomerInfo(CustomerInfo info) {
    final e = info.entitlements.all[entitlementId];
    final active = e?.isActive ?? false;
    DateTime? exp;
    if (e?.expirationDate != null) {
      exp = DateTime.tryParse(e!.expirationDate!);
    }
    return SubscriptionSnapshot(
      tier: active ? SubscriptionTier.pro : SubscriptionTier.free,
      expiryMs: exp?.millisecondsSinceEpoch,
      planLabel: active ? 'Pro' : 'Free',
      productId: e?.productIdentifier,
    );
  }

  void _push(CustomerInfo info) => _ctrl.add(_fromCustomerInfo(info));

  @override
  Stream<SubscriptionSnapshot> subscriptionState() async* {
    try {
      final info = await Purchases.getCustomerInfo();
      yield _fromCustomerInfo(info);
    } catch (_) {
      yield const SubscriptionSnapshot(planLabel: 'Free');
    }
    yield* _ctrl.stream;
  }

  @override
  Future<SubscriptionSnapshot> refreshEntitlements() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final snap = _fromCustomerInfo(info);
      _ctrl.add(snap);
      return snap;
    } catch (_) {
      const snap = SubscriptionSnapshot(planLabel: 'Free');
      _ctrl.add(snap);
      return snap;
    }
  }

  Future<void> _purchasePackage(Package? pkg) async {
    if (pkg == null) {
      throw StateError('No RevenueCat offering configured');
    }
    await Purchases.purchasePackage(pkg);
    await refreshEntitlements();
  }

  @override
  Future<void> selectFree() async {
    // Free tier is the default when no entitlement is active.
    await refreshEntitlements();
  }

  @override
  Future<void> purchaseStandard() async {
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    final pkg = current?.monthly ??
        (current != null && current.availablePackages.isNotEmpty
            ? current.availablePackages.first
            : null);
    await _purchasePackage(pkg);
  }

  @override
  Future<void> purchasePro() async {
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    final pkg = current?.annual ??
        (current != null && current.availablePackages.isNotEmpty
            ? current.availablePackages.first
            : null);
    await _purchasePackage(pkg);
  }

  @override
  Future<void> purchaseMonthly() => purchaseStandard();

  @override
  Future<void> purchaseYearly() => purchasePro();

  @override
  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
    await refreshEntitlements();
  }

  void dispose() => _ctrl.close();
}
