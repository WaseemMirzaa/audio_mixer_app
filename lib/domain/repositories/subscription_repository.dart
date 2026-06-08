enum SubscriptionTier {
  free,
  standard,
  pro,
}

extension SubscriptionTierLimits on SubscriptionTier {
  /// `null` means unlimited mixed audio tracks.
  int? get maxMixTracks => switch (this) {
        SubscriptionTier.free => 2,
        SubscriptionTier.standard => 8,
        SubscriptionTier.pro => null,
      };

  String get displayName => switch (this) {
        SubscriptionTier.free => 'Free',
        SubscriptionTier.standard => 'Standard',
        SubscriptionTier.pro => 'Pro',
      };
}

class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    this.tier = SubscriptionTier.free,
    this.expiryMs,
    this.planLabel,
    this.productId,
    this.trialEndsMs,
  });

  final SubscriptionTier tier;
  final int? expiryMs;
  final String? planLabel;
  final String? productId;
  final int? trialEndsMs;

  bool get isPro => tier == SubscriptionTier.pro;

  bool get isPaid => tier != SubscriptionTier.free;

  int? get maxMixTracks => tier.maxMixTracks;

  bool get isOnTrial =>
      trialEndsMs != null && trialEndsMs! > DateTime.now().millisecondsSinceEpoch;
}

abstract class SubscriptionRepository {
  Stream<SubscriptionSnapshot> subscriptionState();

  Future<SubscriptionSnapshot> refreshEntitlements();

  Future<void> selectFree();

  Future<void> purchaseStandard();

  Future<void> purchasePro();

  Future<void> purchaseMonthly();

  Future<void> purchaseYearly();

  Future<void> restorePurchases();
}
