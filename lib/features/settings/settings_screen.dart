import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../export_import/export_import_ui.dart';
import '../paywall/pro_screen.dart';
import '../paywall/pro_service.dart';
import '../whatsapp_import/whatsapp_import_screen.dart';
import 'privacy_screen.dart';

const kSourceUrl = 'https://github.com/johngospel003/tibb';
const kAppVersion = '0.1.0';

/// Settings (design S15). Few options on purpose.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.settings, s.pro]),
        builder: (context, _) {
          final c = context.colors;
          return ListView(padding: const EdgeInsets.fromLTRB(Space.s400, 0, Space.s400, Space.s1000), children: [
            const SectionLabel('Tibb Pro'),
            ListGroup(children: [
              TibbRow(
                icon: TibbIcons.pro,
                title: 'Tibb Pro',
                value: s.pro.isPro ? (s.pro.plan == ProPlan.lifetime ? 'Lifetime' : 'Yearly') : 'Free',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProScreen())),
              ),
            ]),
            const SectionLabel('Appearance'),
            ListGroup(children: [
              Padding(
                padding: const EdgeInsets.all(Space.s400),
                child: Row(children: [
                  Icon(TibbIcons.palette, color: c.textSecondary),
                  const SizedBox(width: Space.s300),
                  Expanded(child: Text('Theme', style: context.type.bodyMd)),
                  SizedBox(
                    width: 200,
                    child: TibbSegmented<ThemeMode>(
                      segments: const [
                        (ThemeMode.system, 'Auto'),
                        (ThemeMode.light, 'Light'),
                        (ThemeMode.dark, 'Dark'),
                      ],
                      selected: s.settings.themeMode,
                      onChanged: (v) => s.settings.themeMode = v,
                    ),
                  ),
                ]),
              ),
              TibbRow(
                icon: TibbIcons.eyeOff,
                title: 'Hide unreviewed counts',
                subtitle: 'Keep the dots, drop the numbers.',
                trailing: Switch(
                  value: s.settings.hideUnreviewedCounts,
                  onChanged: (v) => s.settings.hideUnreviewedCounts = v,
                ),
              ),
            ]),
            const SectionLabel('Your data'),
            ListGroup(children: [
              TibbRow(icon: TibbIcons.exportIcon, title: 'Export everything', subtitle: 'Always free', onTap: () => showExportSheet(context)),
              TibbRow(icon: TibbIcons.importIcon, title: 'Import a Tibb export', onTap: () => startImport(context)),
              TibbRow(
                icon: TibbIcons.chat,
                title: 'Import from WhatsApp',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const WhatsAppImportScreen())),
              ),
            ]),
            const SectionLabel('Privacy'),
            ListGroup(children: [
              TibbRow(
                icon: TibbIcons.shield,
                title: 'How Tibb keeps things private',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen())),
              ),
            ]),
            const SectionLabel('About'),
            ListGroup(children: [
              TibbRow(icon: TibbIcons.info, title: 'Version', value: kAppVersion, trailing: const SizedBox()),
              TibbRow(
                icon: TibbIcons.link,
                title: 'Source code',
                subtitle: 'Tibb is open source',
                onTap: () => launchUrl(Uri.parse(kSourceUrl), mode: LaunchMode.externalApplication),
              ),
              TibbRow(
                icon: TibbIcons.file,
                title: 'Open-source licenses',
                onTap: () => showLicensePage(context: context, applicationName: 'Tibb', applicationVersion: kAppVersion),
              ),
            ]),
          ]);
        },
      ),
    );
  }
}
