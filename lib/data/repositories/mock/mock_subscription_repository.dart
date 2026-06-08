import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/subscription_repository.dart';
import '../../local/prefs_keys.dart';

class MockSubscriptionRepository implements SubscriptionRepository {
  MockSubscriptionRepository(this._prefs) {
    _emit();
  }

  static const _tierKey = 'mock_subscription_tier';
  static const _trialEndsKey = 'mock_trial_ends_ms';

  final SharedPreferences _prefs;
  final _ctrl = StreamController<SubscriptionSnapshot>.broadcast(sync: true);

  SubscriptionTier _readTier() {
    final raw = _prefs.getString(_tierKey);
    return switch (raw) {
      'standard' => SubscriptionTier.standard,
      'pro' => SubscriptionTier.pro,
      _ => SubscriptionTier.free,
    };
  }

  int? _readTrialEndsMs() => _prefs.getInt(_trialEndsKey);

  SubscriptionSnapshot _snapshot() {
    final tier = _readTier();
    final trialEnds = _readTrialEndsMs();
    final onTrial = trialEnds != null &&
        trialEnds > DateTime.now().millisecondsSinceEpoch;
    final expiry = onTrial
        ? trialEnds
        : tier == SubscriptionTier.free
            ? null
            : DateTime.now()
                .add(Duration(days: tier == SubscriptionTier.pro ? 365 : 30))
                .millisecondsSinceEpoch;

    return SubscriptionSnapshot(
      tier: tier,
      planLabel: '${tier.displayName} (mock)',
      expiryMs: expiry,
      trialEndsMs: onTrial ? trialEnds : null,
      productId: tier == SubscriptionTier.free
          ? null
          : 'mock_${tier.name}',
    );
  }

  void _emit() => _ctrl.add(_snapshot());

  Future<void> _setTier(SubscriptionTier tier, {bool withTrial = false}) async {
    await _prefs.setString(_tierKey, tier.name);
    if (withTrial && tier != SubscriptionTier.free) {
      await _prefs.setInt(
        _trialEndsKey,
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
      );
    } else {
      await _prefs.remove(_trialEndsKey);
    }
    // Legacy flag used by older dev tooling.
    await _prefs.setBool('mock_is_pro', tier == SubscriptionTier.pro);
    _emit();
  }

  @override
  Stream<SubscriptionSnapshot> subscriptionState() async* {
    yield _snapshot();
    yield* _ctrl.stream;
  }

  @override
  Future<SubscriptionSnapshot> refreshEntitlements() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _emit();
    return _snapshot();
  }

  @override
  Future<void> selectFree() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _setTier(SubscriptionTier.free);
  }

  @override
  Future<void> purchaseStandard() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _setTier(SubscriptionTier.standard, withTrial: true);
  }

  @override
  Future<void> purchasePro() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _setTier(SubscriptionTier.pro, withTrial: true);
  }

  @override
  Future<void> purchaseMonthly() => purchaseStandard();

  @override
  Future<void> purchaseYearly() => purchasePro();

  @override
  Future<void> restorePurchases() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _emit();
  }

  Future<void> resetProFlag() async {
    await _prefs.remove(_tierKey);
    await _prefs.remove(_trialEndsKey);
    await _prefs.remove('mock_is_pro');
    _emit();
  }

  Future<void> setSimulatePurchaseFailure(bool v) async {
    await _prefs.setBool('mock_purchase_fail', v);
  }

  bool get simulatePurchaseFailure =>
      _prefs.getBool('mock_purchase_fail') ?? false;

  bool get simulateOffline => _prefs.getBool(PrefsKeys.simulateOffline) ?? false;

  Future<void> setSimulateOffline(bool v) async {
    await _prefs.setBool(PrefsKeys.simulateOffline, v);
  }

  bool get simulateSyncFail =>
      _prefs.getBool(PrefsKeys.simulateSyncFail) ?? false;

  Future<void> setSimulateSyncFail(bool v) async {
    await _prefs.setBool(PrefsKeys.simulateSyncFail, v);
  }

  void dispose() => _ctrl.close();
}
