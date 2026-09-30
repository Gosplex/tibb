import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/tibb_button.dart';
import 'paywall_sheet.dart';
import 'pro_service.dart';

/// Settings → Tibb Pro (design S16). Status, restore, and store management.
class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pro = AppScope.of(context).pro;
    return Scaffold(
      appBar: AppBar(title: const Text('Tibb Pro')),
      body: ListenableBuilder(
        listenable: pro,
        builder: (context, _) {
          final c = context.colors;
          final t = context.type;
          return ListView(
            padding: const EdgeInsets.all(Space.s400),
            children: [
              if (pro.isPro) ...[
                InfoCard(
                  tone: InfoTone.success,
                  icon: TibbIcons.pro,
                  title: pro.plan == ProPlan.lifetime ? 'Pro · Lifetime' : 'Pro · Yearly',
                  body: pro.plan == ProPlan.lifetime
                      ? 'Paid once. Yours forever.'
                      : pro.renewsAt == null
                          ? 'Active.'
                          : 'Renews ${formatDate(pro.renewsAt!.toLocal())}.',
                ),
                const SizedBox(height: Space.s400),
                if (pro.managementUrl != null)
                  TibbButton(
                    label: 'Manage subscription',
                    variant: TibbButtonVariant.tertiary,
                    onPressed: () => launchUrl(Uri.parse(pro.managementUrl!), mode: LaunchMode.externalApplication),
                  ),
              ] else ...[
                Text('Free', style: t.titleLg),
                const SizedBox(height: Space.s100),
                Text('Text and links, one box, export and WhatsApp text import.',
                    style: t.bodyMd.copyWith(color: c.textSecondary)),
                const SizedBox(height: Space.s600),
                TibbButton(
                  label: 'See Tibb Pro',
                  icon: TibbIcons.pro,
                  onPressed: () => ensurePro(context, PaywallReason.settings),
                ),
              ],
              const SizedBox(height: Space.s300),
              TibbButton(
                label: 'Restore purchase',
                variant: TibbButtonVariant.ghost,
                onPressed: pro.isConfigured
                    ? () async {
                        final ok = await pro.restore();
                        if (context.mounted) {
                          showToast(context, ok ? 'Pro restored.' : 'No purchase found for this account.');
                        }
                      }
                    : null,
              ),
              const SizedBox(height: Space.s600),
              InfoCard(
                tone: InfoTone.info,
                title: 'If Pro ever ends',
                body: 'Nothing you saved is locked away. You can still open everything, and export is always free. '
                    'Only creating new Pro items pauses.',
              ),
              if (!pro.isConfigured) ...[
                const SizedBox(height: Space.s400),
                const InfoCard(
                  tone: InfoTone.warning,
                  title: "Purchases aren't set up in this build",
                  body: 'Run with a RevenueCat key: flutter run --dart-define-from-file=env.json',
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
