// The paywall (design §9.15 / S14), built from scratch on RevenueCat
// offerings. Rules it keeps: context line first, prices from the store,
// one CTA, Restore always visible, cancel is never scolded, and closing the
// sheet always returns the user to exactly where they were.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/illustrations.dart';
import '../../design/widgets/tibb_button.dart';
import 'pro_service.dart';
import '../../core/util/platform_copy.dart';

/// Every paywall trigger. `placement` is the RevenueCat placement id and the
/// paywall id reported with impressions.
enum PaywallReason {
  bridge('bridge', 'Open Tibb on your computer', 'Open on computer'),
  secondBox('second_box', 'Keep work and life apart', 'Create your box'),
  media('media', 'Save photos, videos, voice and files', 'Keep going'),
  voice('voice', 'Save voice memos', 'Record a memo'),
  lock('lock', 'Lock the boxes that are just for you', 'Lock your box'),
  whatsappMedia('whatsapp_media', 'Bring your WhatsApp photos and files too', 'Continue import'),
  soft('soft_prompt', 'Everything Tibb can do', 'Continue'),
  settings('settings', 'Everything Tibb can do', 'Continue');

  const PaywallReason(this.placement, this.line, this.continueLabel);
  final String placement;

  /// Contextual headline (design S16): leads with what the user reached for.
  final String line;

  /// The success button finishes the job the user started (design J4 RULE).
  final String continueLabel;

  Illustration get art => switch (this) {
        PaywallReason.bridge => Illustration.phoneLaptop,
        PaywallReason.lock => Illustration.lockedBox,
        PaywallReason.whatsappMedia => Illustration.chatToBox,
        _ => Illustration.openBox,
      };
}

const _termsUrl = 'https://tibb.app/terms';
const _privacyUrl = 'https://tibb.app/privacy';

/// Returns true if the user has Pro (already, or after this paywall).
Future<bool> ensurePro(BuildContext context, PaywallReason reason) async {
  final pro = AppScope.of(context).pro;
  if (pro.isPro) return true;
  await showTibbSheet<void>(context, fullHeight: true, builder: (_) => PaywallSheet(reason: reason));
  return pro.isPro;
}

enum _Phase { loading, ready, failed, notConfigured, purchasing, success }

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key, required this.reason});
  final PaywallReason reason;

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  _Phase _phase = _Phase.loading;
  PaywallOffer _offer = const PaywallOffer();
  Package? _selected;
  String? _inlineMessage;
  bool _restoring = false;

  ProService get _pro => AppScope.of(context).pro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (!_pro.isConfigured) {
      setState(() => _phase = _Phase.notConfigured);
      return;
    }
    setState(() {
      _phase = _Phase.loading;
      _inlineMessage = null;
    });
    try {
      final offer = await _pro.loadOfferings(placement: widget.reason.placement);
      if (!mounted) return;
      if (!offer.isEmpty) _pro.trackPaywallShown('tibb_${widget.reason.placement}');
      setState(() {
        _offer = offer;
        _selected = offer.lifetime ?? offer.yearly; // lifetime pre-selected (brief §9.2)
        _phase = offer.isEmpty ? _Phase.failed : _Phase.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _buy() async {
    final pkg = _selected;
    if (pkg == null) return;
    setState(() {
      _phase = _Phase.purchasing;
      _inlineMessage = null;
    });
    final outcome = await _pro.purchase(pkg);
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        HapticFeedback.mediumImpact();
        Future<void>.delayed(const Duration(milliseconds: 80), HapticFeedback.lightImpact);
        setState(() => _phase = _Phase.success);
      case PurchaseOutcome.cancelled:
        // Cancel is a choice, not an error: no message (design §9.15).
        setState(() => _phase = _Phase.ready);
      case PurchaseOutcome.failed:
        setState(() {
          _phase = _Phase.ready;
          _inlineMessage = "The purchase didn't go through. You weren't charged.";
        });
      case PurchaseOutcome.notConfigured:
        setState(() => _phase = _Phase.notConfigured);
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final found = await _pro.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (found) {
      setState(() => _phase = _Phase.success);
    } else {
      showToast(context, 'No purchase found for this account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surfaceOverlay,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: context.motion(Motion.slow),
          child: _phase == _Phase.success
              ? _SuccessView(
                  key: const ValueKey('ok'),
                  reason: widget.reason,
                  lifetime: _pro.plan == ProPlan.lifetime,
                  renewsAt: _pro.renewsAt,
                )
              : _offerView(context),
        ),
      ),
    );
  }

  Widget _offerView(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final busy = _phase == _Phase.purchasing;
    return Column(
      key: const ValueKey('offer'),
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(Space.s200),
            child: TibbIconButton(
              icon: TibbIcons.close,
              label: 'Close',
              onPressed: busy ? null : () => Navigator.of(context).pop(),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.s600),
            children: [
              // Illustration, then "Unlock Tibb.", then the contextual line last,
              // so it's the focal point (design §10.3 Paywall).
              _Staggered(delay: 120, child: Center(child: TibbIllustration(widget.reason.art, width: 150))),
              const SizedBox(height: Space.s400),
              Semantics(
                header: true,
                child: Text('Unlock Tibb.', style: t.displayMd, textAlign: TextAlign.center),
              ),
              const SizedBox(height: Space.s200),
              _Staggered(
                delay: 220,
                child: Text(widget.reason.line, style: t.titleSm, textAlign: TextAlign.center),
              ),
              const SizedBox(height: Space.s100),
              Text('One payment. No account. Your stuff stays yours.',
                  style: t.bodyMd.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: Space.s600),
              ..._benefits(context),
              const SizedBox(height: Space.s600),
              ..._plans(context),
              if (_inlineMessage != null) ...[
                const SizedBox(height: Space.s300),
                Text(_inlineMessage!, style: t.error.copyWith(color: c.errorFg), textAlign: TextAlign.center),
              ],
              const SizedBox(height: Space.s400),
              InfoCard(
                tone: InfoTone.success,
                icon: TibbIcons.exportIcon,
                title: 'Your stuff is always yours',
                body: 'Everything you save stays on this phone and exports free, forever — Pro or not.',
              ),
              const SizedBox(height: Space.s600),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s600, Space.s200, Space.s600, Space.s200),
          child: Column(children: [
            if (_phase == _Phase.ready || busy)
              TibbButton(
                label: _selected == null
                    ? 'Get Tibb Pro'
                    : 'Get Tibb Pro — ${_selected!.storeProduct.priceString}',
                loading: busy,
                onPressed: _selected == null ? null : _buy,
              ),
            if (_phase == _Phase.ready || busy) ...[
              const SizedBox(height: Space.s200),
              Text(
                  _selected?.packageType == PackageType.lifetime
                      ? 'One payment. No subscription.'
                      : '${_selected?.storeProduct.priceString ?? ''} billed yearly. Renews automatically until you cancel in ${PlatformCopy.store}.',
                  textAlign: TextAlign.center,
                  style: t.caption.copyWith(color: c.textTertiary)),
            ],
            const SizedBox(height: Space.s200),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _LegalLink('Terms', onTap: () => launchUrl(Uri.parse(_termsUrl))),
              Text(' · ', style: t.caption.copyWith(color: c.textTertiary)),
              _LegalLink('Privacy', onTap: () => launchUrl(Uri.parse(_privacyUrl))),
              Text(' · ', style: t.caption.copyWith(color: c.textTertiary)),
              _LegalLink(_restoring ? 'Restoring…' : 'Restore purchase',
                  onTap: _restoring || busy || !_pro.isConfigured ? null : _restore),
            ]),
          ]),
        ),
      ],
    );
  }

  List<Widget> _benefits(BuildContext context) {
    final rows = [
      (TibbIcons.bridge, 'Open Tibb on your computer', 'Drag files in from your laptop. No cloud, no cable.'),
      (TibbIcons.clipboard, 'Clipboard between phone and computer', 'Copy a code on one, paste it on the other.'),
      (TibbIcons.image, 'Photos, videos, voice and files', 'Save anything, not just text.'),
      (TibbIcons.box, 'Unlimited boxes', 'Work, recipes, receipts — each in its own box.'),
      (TibbIcons.lock, 'Locked private boxes', 'Opened with ${PlatformCopy.biometricShort}. Hidden from search and your computer.'),
      (TibbIcons.pro, 'Pay once, no subscription needed', 'Tibb has no servers to pay for, so lifetime is simply fair.'),
    ];
    final c = context.colors;
    return [
      for (final (icon, title, body) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s400),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: c.highlight, borderRadius: BorderRadius.circular(Radii.sm)),
              child: Icon(icon, size: 20, color: c.textPrimary),
            ),
            const SizedBox(width: Space.s300),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.type.titleXs),
                Text(body, style: context.type.bodySm.copyWith(color: c.textSecondary)),
              ]),
            ),
          ]),
        ),
    ];
  }

  List<Widget> _plans(BuildContext context) {
    final c = context.colors;
    switch (_phase) {
      case _Phase.loading:
        return [
          for (var i = 0; i < 2; i++)
            Container(
              height: 88,
              margin: const EdgeInsets.only(bottom: Space.s300),
              decoration: BoxDecoration(color: c.skeletonBase, borderRadius: BorderRadius.circular(Radii.lg)),
            ),
        ];
      case _Phase.failed:
        return [
          InfoCard(
            tone: InfoTone.warning,
            title: "Couldn't load prices",
            body: 'Check your connection and try again.',
            action: TibbButton(
              label: 'Try again',
              variant: TibbButtonVariant.tertiary,
              size: TibbButtonSize.sm,
              expand: false,
              onPressed: _load,
            ),
          ),
        ];
      case _Phase.notConfigured:
        return [
          const InfoCard(
            tone: InfoTone.info,
            title: "Purchases aren't set up in this build",
            body: 'Add a RevenueCat API key to env.json and run with --dart-define-from-file=env.json. '
                'Everything free keeps working.',
          ),
        ];
      case _Phase.ready:
      case _Phase.purchasing:
      case _Phase.success:
        return [
          if (_offer.lifetime != null)
            _PlanCard(
              package: _offer.lifetime!,
              title: 'Lifetime',
              subtitle: 'Pay once. Yours forever.',
              tag: 'Launch price',
              selected: _selected == _offer.lifetime,
              onTap: _phase == _Phase.purchasing ? null : () => setState(() => _selected = _offer.lifetime),
            ),
          if (_offer.yearly != null)
            _PlanCard(
              package: _offer.yearly!,
              title: 'Yearly',
              subtitle: 'Billed once a year.',
              selected: _selected == _offer.yearly,
              onTap: _phase == _Phase.purchasing ? null : () => setState(() => _selected = _offer.yearly),
            ),
        ];
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.package,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.tag,
  });

  final Package package;
  final String title;
  final String subtitle;
  final String? tag;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s300),
      child: Semantics(
        selected: selected,
        button: true,
        label: '$title, ${package.storeProduct.priceString}. $subtitle',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: AnimatedContainer(
            duration: context.motion(Motion.fast),
            padding: const EdgeInsets.all(Space.s400),
            decoration: BoxDecoration(
              color: selected ? (c.isDark ? c.surfaceSunken : Palette.saffron50) : c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: selected ? c.borderSelected : c.borderDefault,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: context.motion(Motion.fast),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.actionPrimary : Colors.transparent,
                  border: Border.all(color: selected ? c.actionPrimary : c.borderInput, width: 2),
                ),
                child: selected ? Icon(TibbIcons.check, size: 14, color: c.textOnAccent) : null,
              ),
              const SizedBox(width: Space.s300),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(title, style: t.titleSm),
                    if (tag != null) ...[
                      const SizedBox(width: Space.s200),
                      TibbTag(label: tag!, fg: c.textOnAccent, bg: c.actionPrimary),
                    ],
                  ]),
                  const SizedBox(height: Space.s050),
                  Text(subtitle, style: t.bodySm.copyWith(color: c.textSecondary)),
                ]),
              ),
              Text(package.storeProduct.priceString, style: t.numberPrice.copyWith(fontSize: 22)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink(this.label, {required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s300, horizontal: Space.s050),
        child: Text(label,
            style: context.type.caption.copyWith(
              color: onTap == null ? c.textDisabled : c.textSecondary,
              decoration: TextDecoration.underline,
            )),
      ),
    );
  }
}

/// Fades and lifts a child in after [delay] ms (the paywall's staged entrance).
class _Staggered extends StatelessWidget {
  const _Staggered({required this.delay, required this.child});
  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    final total = delay + Motion.normal.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (_, v, c) {
        final t = ((v * total - delay) / Motion.normal.inMilliseconds).clamp(0.0, 1.0);
        final e = Motion.decelerate.transform(t);
        return Opacity(opacity: e, child: Transform.translate(offset: Offset(0, 8 * (1 - e)), child: c));
      },
      child: child,
    );
  }
}

/// "You're in." (design S17): sparkle burst, then a button that continues
/// what the user was doing. Auto-continues after 2.5 s.
class _SuccessView extends StatefulWidget {
  const _SuccessView({super.key, required this.reason, required this.lifetime, this.renewsAt});
  final PaywallReason reason;
  final bool lifetime;
  final DateTime? renewsAt;

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView> {
  bool _left = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wait = context.reduceMotion ? Duration.zero : const Duration(milliseconds: 2500);
      Future<void>.delayed(wait, _continue);
    });
  }

  void _continue() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final renew = widget.renewsAt;
    return Padding(
      padding: const EdgeInsets.all(Space.s600),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 160,
            child: Stack(alignment: Alignment.center, children: [
              const _SparkleBurst(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1),
                duration: context.motion(Motion.emphasis),
                curve: Motion.settle,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: const LidClose(kind: Illustration.closedBox, width: 150),
              ),
            ]),
          ),
          const SizedBox(height: Space.s600),
          Semantics(liveRegion: true, child: Text("You're in.", style: context.type.displayMd)),
          const SizedBox(height: Space.s200),
          Text(
            widget.lifetime
                ? 'Tibb Pro is yours — for good.'
                : renew == null
                    ? 'Tibb Pro is active.'
                    : 'Tibb Pro is active. Renews ${formatDate(renew)}.',
            style: context.type.bodyLg.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.s1000),
          TibbButton(label: widget.reason.continueLabel, onPressed: _continue),
        ],
      ),
    );
  }
}

/// Six small saffron squares drifting outward 24 dp and fading (not confetti).
class _SparkleBurst extends StatelessWidget {
  const _SparkleBurst();

  @override
  Widget build(BuildContext context) {
    final color = context.colors.actionPrimary;
    if (context.reduceMotion) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.emphasis,
      curve: Motion.decelerate,
      builder: (_, v, __) => Stack(alignment: Alignment.center, children: [
        for (var i = 0; i < 6; i++)
          Transform.translate(
            offset: Offset.fromDirection(i * 3.14159 / 3 - 1.2, 56 + 24 * v),
            child: Opacity(
              opacity: (1 - v).clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: 0.785,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
