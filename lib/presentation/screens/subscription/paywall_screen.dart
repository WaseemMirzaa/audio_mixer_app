import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/mock/mock_subscription_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/guest_sign_in_dialog.dart';
import '../../widgets/sa_glass.dart';
import 'paywall_plan_glyphs.dart';

enum _PaywallPlan { free, standard, pro }

/// Cosmetic billing-period toggle. The mock repo has no yearly SKU, so this only
/// drives the highlighted segment and the displayed price labels — it never
/// changes which purchase call runs.
enum _BillingPeriod { monthly, yearly }

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _busy = false;
  _PaywallPlan _selected = _PaywallPlan.pro;
  _BillingPeriod _period = _BillingPeriod.monthly;

  Future<void> _subscribePlan(_PaywallPlan plan) async {
    setState(() => _selected = plan);
    await _continue();
  }

  Future<void> _continue() async {
    // Guest guard — guests must sign in before purchasing.
    final user = ref.read(authStateProvider).valueOrNull;
    if (user?.isGuest == true) {
      if (!mounted) return;
      showGuestSignInDialog(context);
      return;
    }
    final repo = ref.read(subscriptionRepositoryProvider);
    switch (_selected) {
      case _PaywallPlan.free:
        await _run(repo.selectFree);
      case _PaywallPlan.standard:
        await _run(repo.purchaseStandard);
      case _PaywallPlan.pro:
        await _run(repo.purchasePro);
    }
  }

  Future<void> _restore() async {
    // Guest guard — guests must sign in before restoring purchases.
    final user = ref.read(authStateProvider).valueOrNull;
    if (user?.isGuest == true) {
      if (!mounted) return;
      showGuestSignInDialog(context);
      return;
    }
    await _run(
      () => ref.read(subscriptionRepositoryProvider).restorePurchases(),
    );
  }

  Future<void> _run(Future<void> Function() fn) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    if (repo is MockSubscriptionRepository && repo.simulatePurchaseFailure) {
      if (!mounted) return;
      context.push('/error?msg=${Uri.encodeComponent('Payment failure')}');
      return;
    }
    setState(() => _busy = true);
    try {
      await fn();
      ref.invalidate(subscriptionStreamProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selected == _PaywallPlan.free
                ? 'Using Free plan'
                : '7-day free trial started',
          ),
        ),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      context.push('/error?msg=${Uri.encodeComponent('Purchase failed')}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yearly = _period == _BillingPeriod.yearly;

    return SaGlassScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SaBackHeader(
              title: 'Membership',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                children: [
                  const _PaywallHero(),
                  const SizedBox(height: 18),
                  _BillingTabs(
                    period: _period,
                    onChanged: (p) => setState(() => _period = p),
                  ),
                  const SizedBox(height: 18),
                  // Basic → free
                  _PlanCard(
                    iconGlyph: PaywallBasicGlyph(
                        color: SaGlass.of(context).cyan, width: 22),
                    name: 'Basic',
                    nameColor: null, // textPrimary
                    sub: '2 hours listening time per month',
                    subColor: null, // textMuted
                    price: '£0.00',
                    priceColor: null, // textPrimary
                    priceNote: 'Free forever',
                    features: const [
                      'Mix 2 audio tracks',
                      'Basic sound library',
                      '3 saved sessions',
                      'Standard quality',
                      'Ads supported',
                    ],
                    featured: false,
                    outlinedButton: true,
                    buttonLabel: 'Current Plan',
                    trialNote: null,
                    busy: _busy,
                    onTap: () => setState(() => _selected = _PaywallPlan.free),
                    onAction: () => _subscribePlan(_PaywallPlan.free),
                  ),
                  const SizedBox(height: 14),
                  // Plus → standard (featured)
                  _PlanCard(
                    iconGlyph: PaywallPlusGlyph(
                        color: SaGlass.of(context).cyan, width: 32),
                    name: 'Plus',
                    nameColor: null,
                    sub: '15 hours listening time per month',
                    subColorIsCyan: true,
                    price: yearly ? '£3.33' : '£4.99',
                    priceColorIsCyan: true,
                    priceNote: yearly ? 'per month, billed yearly' : 'per month',
                    features: const [
                      'All Basic features',
                      'Access to Theme Tunes',
                      'Premium sound library',
                      'Unlimited saved sessions',
                      'Sleep timer & fade out',
                      'Ad-free experience',
                    ],
                    featured: true,
                    badge: 'MOST POPULAR',
                    outlinedButton: false,
                    buttonLabel: 'Start Free Trial',
                    trialNote: '7 days free, cancel anytime',
                    busy: _busy,
                    onTap: () =>
                        setState(() => _selected = _PaywallPlan.standard),
                    onAction: () => _subscribePlan(_PaywallPlan.standard),
                  ),
                  const SizedBox(height: 14),
                  // Pro → pro
                  _PlanCard(
                    iconGlyph: const PaywallProGlyph(width: 32),
                    name: 'Pro',
                    nameColorIsCyan: true,
                    sub: 'Unlimited listening time',
                    subColorIsCyan: true,
                    price: yearly ? '£4.66' : '£6.99',
                    priceColorIsCyan: true,
                    priceNote: yearly ? 'per month, billed yearly' : 'per month',
                    features: const [
                      'All Plus features',
                      'Unlimited Theme Tunes',
                      'All premium sound packs',
                      'AI SmartBlend™',
                      'Advanced mix settings',
                      'Offline listening',
                      'Cloud sync across devices',
                      'Priority support',
                    ],
                    featured: false,
                    outlinedButton: false,
                    buttonLabel: 'Start Free Trial',
                    trialNote: '7 days free, cancel anytime',
                    busy: _busy,
                    onTap: () => setState(() => _selected = _PaywallPlan.pro),
                    onAction: () => _subscribePlan(_PaywallPlan.pro),
                  ),
                  const SizedBox(height: 18),
                  const _AllPlansFooter(),
                  const SizedBox(height: 10),
                  _RestoreRow(busy: _busy, onRestore: _restore),
                  const SaLegalFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaywallHero extends StatelessWidget {
  const _PaywallHero();

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 4),
        Text(
          'Unlock your perfect sound',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: glass.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'More time. More sounds. More you.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: glass.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// Rounded pill bar with 3 segments: Monthly | Yearly | Save 33%.
/// "Save 33%" is a cosmetic hint that selects the yearly period.
class _BillingTabs extends StatelessWidget {
  const _BillingTabs({required this.period, required this.onChanged});

  final _BillingPeriod period;
  final ValueChanged<_BillingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: glass.isDark
            ? Colors.white.withValues(alpha: 0.08)
            : glass.glassBottom,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glass.glassBorder, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: 'Monthly',
              active: period == _BillingPeriod.monthly,
              onTap: () => onChanged(_BillingPeriod.monthly),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'Yearly',
              active: period == _BillingPeriod.yearly,
              onTap: () => onChanged(_BillingPeriod.yearly),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'Save 33%',
              active: false,
              labelColor: glass.cyan,
              onTap: () => onChanged(_BillingPeriod.yearly),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
    this.labelColor,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: glass.continueGradient,
                  )
                : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : (labelColor ?? glass.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.iconGlyph,
    required this.name,
    required this.sub,
    required this.price,
    required this.priceNote,
    required this.features,
    required this.featured,
    required this.outlinedButton,
    required this.buttonLabel,
    required this.trialNote,
    required this.busy,
    required this.onTap,
    required this.onAction,
    this.nameColor,
    this.nameColorIsCyan = false,
    this.subColor,
    this.subColorIsCyan = false,
    this.priceColor,
    this.priceColorIsCyan = false,
    this.badge,
  });

  final Widget iconGlyph;
  final String name;
  final Color? nameColor;
  final bool nameColorIsCyan;
  final String sub;
  final Color? subColor;
  final bool subColorIsCyan;
  final String price;
  final Color? priceColor;
  final bool priceColorIsCyan;
  final String priceNote;
  final List<String> features;
  final bool featured;
  final String? badge;
  final bool outlinedButton;
  final String buttonLabel;
  final String? trialNote;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);

    final base = glass.card(radius: 16);
    final decoration = featured
        ? base.copyWith(
            border: Border.all(color: glass.accent, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: glass.accent.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          )
        : base;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: decoration,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (badge != null) ...[
                  _PopularBadge(label: badge!),
                  const SizedBox(height: 14),
                ],
                // Header row: icon tile + name/sub
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: glass.glassBottom,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: glass.glassBorder, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: iconGlyph,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: nameColorIsCyan
                                  ? glass.cyan
                                  : (nameColor ?? glass.textPrimary),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sub,
                            style: TextStyle(
                              color: subColorIsCyan
                                  ? glass.cyan
                                  : (subColor ?? glass.textMuted),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Price row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: priceColorIsCyan
                            ? glass.cyan
                            : (priceColor ?? glass.textPrimary),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      priceNote,
                      style: TextStyle(
                        color: glass.textMeta,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, thickness: 1, color: glass.divider),
                const SizedBox(height: 14),
                _FeatureGrid(features: features),
                const SizedBox(height: 16),
                if (outlinedButton)
                  SaSecondaryButton(
                    label: busy ? '…' : buttonLabel,
                    onPressed: busy ? null : onAction,
                  )
                else
                  SaPrimaryButton(
                    label: busy ? '…' : buttonLabel,
                    onPressed: busy ? null : onAction,
                    enabled: !busy,
                  ),
                if (trialNote != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    trialNote!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: glass.textMeta,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 2-column feature grid with cyan check marks.
class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.features});

  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < features.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < features.length ? 8 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _FeatureItem(features[i])),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < features.length
                    ? _FeatureItem(features[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.check_rounded, size: 13, color: glass.cyan),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: glass.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

/// Centered "MOST POPULAR" badge with thin divider lines on each side.
class _PopularBadge extends StatelessWidget {
  const _PopularBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Row(
      children: [
        Expanded(child: Divider(height: 1, thickness: 1, color: glass.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              color: glass.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(child: Divider(height: 1, thickness: 1, color: glass.divider)),
      ],
    );
  }
}

class _AllPlansFooter extends StatelessWidget {
  const _AllPlansFooter();

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Container(
      decoration: glass.card(radius: 13),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.equalizer_rounded, size: 20, color: glass.cyan),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All plans include',
                    style: TextStyle(
                      color: glass.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mix your audiobook with relaxing background sounds and '
                    'create the perfect atmosphere for any moment.',
                    style: TextStyle(
                      color: glass.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoreRow extends StatelessWidget {
  const _RestoreRow({required this.busy, required this.onRestore});

  final bool busy;
  final Future<void> Function() onRestore;

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return Center(
      child: TextButton(
        onPressed: busy ? null : onRestore,
        style: TextButton.styleFrom(foregroundColor: glass.textMuted),
        child: const Text('Restore Purchases'),
      ),
    );
  }
}
