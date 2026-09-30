// ProService — the only place Tibb talks to RevenueCat. UI reads `isPro` and
// listens for changes; the paywall calls [loadOfferings], [purchase], [restore].
//
// Keys come from --dart-define-from-file=env.json (RC_API_KEY). With no key the
// app still runs fully in the free tier and the paywall says purchases aren't
// set up in this build — it never pretends to sell something it can't.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const String kProEntitlement = 'pro';
const String _apiKey = String.fromEnvironment('RC_API_KEY');

enum ProPlan { none, lifetime, yearly }

enum PurchaseOutcome { success, cancelled, failed, notConfigured }

class PaywallOffer {
  const PaywallOffer({this.lifetime, this.yearly});
  final Package? lifetime;
  final Package? yearly;
  bool get isEmpty => lifetime == null && yearly == null;
}

class ProService extends ChangeNotifier {
  bool _configured = false;
  bool _isPro = false;
  CustomerInfo? _info;

  bool get isConfigured => _configured;
  bool get isPro => _isPro;

  ProPlan get plan {
    final ent = _info?.entitlements.active[kProEntitlement];
    if (ent == null) return ProPlan.none;
    return ent.expirationDate == null ? ProPlan.lifetime : ProPlan.yearly;
  }

  DateTime? get renewsAt {
    final raw = _info?.entitlements.active[kProEntitlement]?.expirationDate;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  String? get managementUrl => _info?.managementURL;

  Future<void> init() async {
    if (_apiKey.isEmpty) {
      debugPrint('Tibb: RC_API_KEY not set — running in free tier without purchases.');
      return;
    }
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_apply);
      _apply(await Purchases.getCustomerInfo());
    } catch (e) {
      // Offline at launch is normal: entitlements refresh when the listener fires.
      debugPrint('Tibb: RevenueCat init failed: $e');
    }
  }

  void _apply(CustomerInfo info) {
    _info = info;
    final pro = info.entitlements.active.containsKey(kProEntitlement);
    if (pro != _isPro) {
      _isPro = pro;
    }
    notifyListeners();
  }

  Offering? _shownOffering;

  /// Loads the offering for a paywall trigger. Each trigger is a RevenueCat
  /// *placement* (e.g. `bridge`, `second_box`), so the dashboard can target a
  /// different offering per moment without an app update. Falls back to
  /// `offerings.current`. Prices always come from the store, never hardcoded.
  Future<PaywallOffer> loadOfferings({String? placement}) async {
    if (!_configured) return const PaywallOffer();
    Offering? offering;
    if (placement != null) {
      try {
        offering = await Purchases.getCurrentOfferingForPlacement(placement);
      } catch (_) {/* placements not set up: use the current offering */}
    }
    offering ??= (await Purchases.getOfferings()).current;
    _shownOffering = offering;
    if (offering == null) return const PaywallOffer();
    return PaywallOffer(lifetime: offering.lifetime, yearly: offering.annual);
  }

  /// Reports that our custom paywall was shown, so RevenueCat's paywall
  /// analytics (impressions → conversions per trigger) work for a paywall we
  /// built ourselves.
  Future<void> trackPaywallShown(String paywallId) async {
    if (!_configured) return;
    try {
      await Purchases.trackCustomPaywallImpression(
        params: CustomPaywallImpressionParams(paywallId: paywallId, offering: _shownOffering),
      );
    } catch (e) {
      debugPrint('Tibb: impression tracking failed: $e');
    }
  }

  Future<PurchaseOutcome> purchase(Package package) async {
    if (!_configured) return PurchaseOutcome.notConfigured;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _apply(result.customerInfo);
      return _isPro ? PurchaseOutcome.success : PurchaseOutcome.failed;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return PurchaseOutcome.cancelled;
      debugPrint('Tibb: purchase failed: $code');
      return PurchaseOutcome.failed;
    }
  }

  /// Returns true if an active Pro entitlement was found.
  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      _apply(await Purchases.restorePurchases());
    } on PlatformException catch (e) {
      debugPrint('Tibb: restore failed: ${PurchasesErrorHelper.getErrorCode(e)}');
    }
    return _isPro;
  }
}
