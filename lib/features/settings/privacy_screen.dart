import 'package:flutter/material.dart';

import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/illustrations.dart';

/// Plain-language privacy facts (design S20). Every line must stay literally true.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const facts = [
      (TibbIcons.box, 'Everything lives on this phone', 'No account, no Tibb server, and Tibb never uploads what you save. Deleting the app deletes your boxes — export first. (On iPhone, your own iCloud device backup can include it, like any app.)'),
      (TibbIcons.bridge, 'Bridge stays on your Wi-Fi', 'Your computer talks straight to this phone. It is plain HTTP on your local network: use it on networks you trust, like home or your own hotspot.'),
      (TibbIcons.lock, 'Locked boxes need your fingerprint or Face ID', 'Their contents aren’t shown, searched or sent to your computer until you unlock them.'),
      (TibbIcons.key, 'Exports can be encrypted', 'AES-256-GCM with a key derived from your password (Argon2id). We can’t reset it — nobody can.'),
      (TibbIcons.pro, 'Purchases go through the app store', 'Apple or Google handles payment; RevenueCat handles the purchase receipt and an anonymous ID. It never sees what you save.'),
      (TibbIcons.shield, 'No analytics, no ads', 'Tibb doesn’t track what you do or what you save.'),
    ];
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(padding: const EdgeInsets.all(Space.s600), children: [
        const Center(child: TibbIllustration(Illustration.lockedBox)),
        const SizedBox(height: Space.s400),
        Text('Yours, and only yours.', style: context.type.displayMd, textAlign: TextAlign.center),
        const SizedBox(height: Space.s1000),
        for (final (icon, title, body) in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s600),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: c.textAccent),
              const SizedBox(width: Space.s400),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: context.type.titleXs),
                  const SizedBox(height: Space.s100),
                  Text(body, style: context.type.bodyMd.copyWith(color: c.textSecondary)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}
