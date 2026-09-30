// Phone side of Tibb Bridge (design S14 / S15, journey J4):
//   first time: what Bridge is + the honest note → Start
//   waiting:    address + pairing code + countdown → "Not connecting?" after 60 s
//   connected:  status card (pairing-success morph), clipboard, locked boxes, Stop
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/platform/tibb_platform.dart';
import '../../core/util/format.dart';
import '../../core/util/platform_copy.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/illustrations.dart';
import '../../design/widgets/tibb_button.dart';
import '../locked/lock_service.dart';
import '../paywall/paywall_sheet.dart';
import 'bridge_server.dart';

const _introSeenFlag = 'bridge_intro_seen';

/// Entry point from the thread's laptop icon. Bridge is a Pro feature; a free
/// user who buys Pro continues straight into Bridge (design J4 RULE).
Future<void> openBridge(BuildContext context) async {
  if (!await ensurePro(context, PaywallReason.bridge)) return;
  if (!context.mounted) return;
  final s = AppScope.of(context);
  final firstTime = !s.repo.flag(_introSeenFlag);
  if (!firstTime && !s.bridge.isRunning) {
    // Deliberately not awaited: the sheet shows the "starting" state.
    s.bridge.start();
  }
  // "Your computer is disconnected." only when one actually was connected.
  var hadComputer = s.bridge.isConnected;
  void track() {
    if (s.bridge.isConnected) hadComputer = true;
  }

  s.bridge.addListener(track);
  await showTibbSheet<void>(context, builder: (_) => const BridgeSheet());
  s.bridge.removeListener(track);
  if (context.mounted && hadComputer && !s.bridge.isConnected) {
    showToast(context, 'Your computer is disconnected.');
  }
}

/// Starts Bridge after the one-time explainer. Permissions are asked here and
/// nowhere else (brief §7.13).
Future<void> _startFromIntro(BuildContext context) async {
  final s = AppScope.of(context);
  s.repo.setFlag(_introSeenFlag);
  await TibbPlatform.instance.requestNotifications();
  await s.bridge.start();
}

class BridgeSheet extends StatelessWidget {
  const BridgeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final bridge = s.bridge;
    return ListenableBuilder(
      listenable: bridge,
      builder: (context, _) {
        final intro = !s.repo.flag(_introSeenFlag) && !bridge.isRunning;
        final Widget body = intro
            ? const _Intro()
            : switch (bridge.status) {
                BridgeStatus.idle || BridgeStatus.starting => const _Starting(),
                BridgeStatus.error => _ErrorView(bridge: bridge),
                BridgeStatus.waiting => _Waiting(bridge: bridge),
                BridgeStatus.connected => _Connected(bridge: bridge),
              };
        final title = intro
            ? null
            : bridge.isConnected
                ? 'Your computer is connected'
                : 'Open this on your computer';
        return SheetScaffold(
          title: title,
          child: AnimatedSwitcher(
            duration: context.motion(Motion.slow),
            switchInCurve: Motion.decelerate,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(sizeFactor: anim, axisAlignment: -1, child: child),
            ),
            child: body,
          ),
        );
      },
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Column(key: const ValueKey('intro'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Center(child: TibbIllustration(Illustration.phoneLaptop)),
      const SizedBox(height: Space.s600),
      Text('Open Tibb on your computer', style: t.headlineHero, textAlign: TextAlign.center),
      const SizedBox(height: Space.s200),
      Text(
        'Your phone becomes a tiny website on your Wi-Fi. Type its address into any browser, '
        'and your boxes appear — drag files in, copy things out.',
        style: t.bodyMd.copyWith(color: c.textSecondary),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: Space.s600),
      const InfoCard(
        tone: InfoTone.connected,
        icon: TibbIcons.wifi,
        title: 'It stays on your Wi-Fi',
        body: 'This never touches the internet. It’s plain, unencrypted HTTP on your local network, '
            'so use it on networks you trust — like home.',
      ),
      if (Platform.isIOS) ...[
        const SizedBox(height: Space.s300),
        InfoCard(tone: InfoTone.info, title: 'Keep Tibb open', body: PlatformCopy.keepOpenReason),
      ],
      const SizedBox(height: Space.s600),
      TibbButton(label: 'Start Bridge', icon: TibbIcons.bridge, onPressed: () => _startFromIntro(context)),
    ]);
  }
}

class _Starting extends StatelessWidget {
  const _Starting();

  @override
  Widget build(BuildContext context) => Padding(
        key: const ValueKey('starting'),
        padding: const EdgeInsets.symmetric(vertical: Space.s1000),
        child: Column(children: [
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.connectedFg)),
          const SizedBox(height: Space.s400),
          Text('Finding your Wi-Fi…', style: context.type.bodyMd.copyWith(color: context.colors.textSecondary)),
        ]),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.bridge});
  final BridgeServer bridge;

  @override
  Widget build(BuildContext context) {
    final noWifi = bridge.error == BridgeError.noWifi;
    return Column(key: const ValueKey('error'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InfoCard(
        tone: InfoTone.warning,
        icon: TibbIcons.wifi,
        title: noWifi ? 'Connect this phone to Wi-Fi' : "Bridge couldn't start",
        body: noWifi
            ? 'Your phone and computer need the same Wi-Fi. No Wi-Fi around? Turn on your phone’s hotspot and join it from your computer.'
            : 'Something on this network blocked Tibb. Try again, or use your phone’s hotspot.',
      ),
      const SizedBox(height: Space.s400),
      TibbButton(
        label: 'Try again',
        onPressed: () async {
          await bridge.stop();
          await bridge.start();
        },
      ),
      const _TroubleshootLink(),
    ]);
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.bridge});
  final BridgeServer bridge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final host = bridge.host ?? '';
    final port = '${bridge.port ?? ''}';
    final url = 'http://${bridge.address}';
    final code = bridge.code ?? '------';
    final left = bridge.codeTimeLeft;
    final slow = bridge.startedAt != null && DateTime.now().difference(bridge.startedAt!) > const Duration(seconds: 60);

    return Column(key: const ValueKey('waiting'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Type this address into any browser on the same Wi-Fi.',
          style: t.bodyMd.copyWith(color: c.textSecondary)),
      const SizedBox(height: Space.s300),
      Container(
        padding: const EdgeInsets.fromLTRB(Space.s400, Space.s400, Space.s200, Space.s400),
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.lg)),
        child: Row(children: [
          Expanded(
            child: Semantics(
              label: 'Address: $url',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'http://', style: t.monoMd.copyWith(color: c.textTertiary)),
                  TextSpan(text: host, style: t.monoXl),
                  TextSpan(text: ':$port', style: t.monoXl.copyWith(color: c.textSecondary)),
                ])),
              ),
            ),
          ),
          TibbIconButton(
            icon: TibbIcons.copy,
            label: 'Copy address',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              HapticFeedback.selectionClick();
              showToast(context, 'Address copied');
            },
          ),
        ]),
      ),
      const SizedBox(height: Space.s100),
      Text('The address changes each time, so it can’t be bookmarked.',
          style: t.caption.copyWith(color: c.textTertiary)),
      const SizedBox(height: Space.s600),
      Text('Then enter this code', style: t.titleSm),
      const SizedBox(height: Space.s300),
      Semantics(
        label: 'Pairing code ${code.split('').join(' ')}',
        excludeSemantics: true,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < code.length; i++) ...[
            if (i == 3) const SizedBox(width: Space.s300),
            Container(
              width: 44,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: Space.s050),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.sm)),
              child: AnimatedSwitcher(
                duration: context.motion(Motion.normal),
                child: Text(code[i], key: ValueKey('$i${code[i]}'), style: t.monoLg),
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: Space.s300),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            value: left.inSeconds / 300,
            strokeWidth: 2,
            color: c.connectedFg,
            backgroundColor: c.surfaceSunken,
          ),
        ),
        const SizedBox(width: Space.s200),
        Text('New code in ${formatDuration(left)}', style: t.caption.copyWith(color: c.textTertiary)),
      ]),
      const SizedBox(height: Space.s600),
      InfoCard(
        tone: InfoTone.connected,
        icon: TibbIcons.wifi,
        title: 'Stays on your Wi-Fi',
        body: Platform.isIOS
            ? 'It never touches the internet. Keep Tibb open on this iPhone while your computer is connected.'
            : 'It never touches the internet. You can switch apps — Tibb stays connected until you stop it.',
      ),
      const SizedBox(height: Space.s400),
      if (slow) ...[
        TibbButton(
          label: 'Not connecting?',
          variant: TibbButtonVariant.tertiary,
          size: TibbButtonSize.md,
          onPressed: () => _openTroubleshooting(context, url),
        ),
        const SizedBox(height: Space.s100),
      ],
      TibbButton(
        label: 'Stop Bridge',
        variant: TibbButtonVariant.ghost,
        size: TibbButtonSize.md,
        onPressed: () async {
          await bridge.stop();
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
      if (!slow) const _TroubleshootLink(),
    ]);
  }
}

class _Connected extends StatelessWidget {
  const _Connected({required this.bridge});
  final BridgeServer bridge;

  Future<void> _toggleShareLocked(BuildContext context, bool value) async {
    final locks = AppScope.of(context).locks;
    if (value) {
      final r = await locks.authenticate('Show locked boxes on your computer');
      if (r != UnlockResult.success) return;
      HapticFeedback.mediumImpact();
    }
    bridge.setShareLocked(value);
  }

  Future<void> _sendClipboard(BuildContext context) async {
    // Always user-initiated: Tibb never reads the clipboard on its own (brief §7.10).
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!context.mounted) return;
    if (text.isEmpty) {
      showToast(context, 'Your clipboard is empty. Copy something first.');
      return;
    }
    AppScope.of(context).repo.addClipboard(text);
    HapticFeedback.lightImpact();
    showToast(context, 'Sent — it’s pinned at the top of the page on your computer.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final s = bridge.session!;
    final locks = AppScope.of(context).locks;
    final hasLocked = AppScope.of(context).repo.boxes().any((b) => b.locked);
    return Column(key: const ValueKey('connected'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Pairing success (design §10.4): the status card settles in with a check.
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: context.motion(Motion.emphasis),
        curve: Motion.settle,
        builder: (context, v, child) => Transform.scale(scale: 0.96 + 0.04 * v, child: Opacity(opacity: v.clamp(0.0, 1.0), child: child)),
        child: Container(
          padding: const EdgeInsets.all(Space.s400),
          decoration: BoxDecoration(color: c.connectedBg, borderRadius: BorderRadius.circular(Radii.lg)),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: c.connectedFg, shape: BoxShape.circle),
              child: Icon(TibbIcons.check, color: c.isDark ? c.background : Colors.white),
            ),
            const SizedBox(width: Space.s300),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(liveRegion: true, child: Text('${s.deviceName} is connected', style: t.titleSm)),
                const SizedBox(height: Space.s050),
                Text('Since ${formatTime(s.connectedAt)} · ${s.received} received',
                    style: t.monoSm.copyWith(color: c.textSecondary)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: Space.s400),
      ListGroup(children: [
        TibbRow(
          icon: TibbIcons.clipboard,
          title: 'Send clipboard',
          subtitle: 'Copy something on this phone, then tap here.',
          onTap: () => _sendClipboard(context),
        ),
        if (hasLocked)
          TibbRow(
            icon: TibbIcons.lock,
            title: 'Show locked boxes on computer',
            subtitle: 'Only for this session. Needs ${PlatformCopy.biometricShort}.',
            trailing: Switch(
              value: locks.shareLockedWithBridge,
              onChanged: (v) => _toggleShareLocked(context, v),
            ),
          ),
      ]),
      const SizedBox(height: Space.s400),
      Text(
        Platform.isIOS
            ? 'Keep Tibb open on this iPhone while you work.'
            : 'You can use other apps. The notification lets you stop Bridge any time.',
        textAlign: TextAlign.center,
        style: t.bodySm.copyWith(color: c.textTertiary),
      ),
      const SizedBox(height: Space.s400),
      TibbButton(
        label: 'Stop Bridge',
        variant: TibbButtonVariant.secondary,
        onPressed: () async {
          await bridge.stop();
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
      const SizedBox(height: Space.s100),
      TibbButton(
        label: 'Disconnect this computer only',
        variant: TibbButtonVariant.ghost,
        size: TibbButtonSize.md,
        onPressed: bridge.disconnectBrowser,
      ),
    ]);
  }
}

void _openTroubleshooting(BuildContext context, [String? url]) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => _Troubleshoot(url: url)));

class _TroubleshootLink extends StatelessWidget {
  const _TroubleshootLink();

  @override
  Widget build(BuildContext context) {
    final bridge = AppScope.of(context).bridge;
    return TibbButton(
      label: 'Can’t connect?',
      variant: TibbButtonVariant.ghost,
      size: TibbButtonSize.sm,
      onPressed: () => _openTroubleshooting(context, bridge.address == null ? null : 'http://${bridge.address}'),
    );
  }
}

/// Bridge troubleshooting (design S15): calm checklist, no blame.
class _Troubleshoot extends StatelessWidget {
  const _Troubleshoot({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final tips = <(IconData, String, String)>[
      (TibbIcons.wifi, 'Same Wi-Fi', 'Your phone and computer must be on the same network. Guest networks often keep devices apart.'),
      (TibbIcons.bridge, 'Try your phone’s hotspot', 'Turn on the hotspot, join it from your computer, then start Bridge again. This works almost everywhere.'),
      (TibbIcons.shield, 'Turn off VPN', 'A VPN on either device can hide them from each other.'),
      (TibbIcons.info, 'Office, campus and café Wi-Fi', 'These often block devices from seeing each other. The hotspot works around it.'),
      if (Platform.isIOS)
        (TibbIcons.settings, 'Allow Local Network', 'iPhone asks once. If you said no: Settings → Privacy & Security → Local Network → turn on Tibb.')
      else
        (TibbIcons.settings, 'Battery saver', 'If your computer drops off when the screen is off, turn off battery optimization for Tibb in Settings → Apps → Tibb → Battery.'),
      (TibbIcons.link, 'Type the address exactly', 'Include http:// and the number after the colon.'),
    ];
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Not connecting?')),
      body: ListView(padding: const EdgeInsets.all(Space.s400), children: [
        ListGroup(children: [
          for (final (icon, title, body) in tips)
            Padding(
              padding: const EdgeInsets.all(Space.s400),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: c.textSecondary),
                const SizedBox(width: Space.s300),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: context.type.titleXs),
                    const SizedBox(height: Space.s050),
                    Text(body, style: context.type.bodySm.copyWith(color: c.textSecondary)),
                  ]),
                ),
              ]),
            ),
        ]),
        if (url != null) ...[
          const SizedBox(height: Space.s600),
          TibbButton(
            label: 'Copy the address',
            icon: TibbIcons.copy,
            variant: TibbButtonVariant.tertiary,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url!));
              showToast(context, 'Address copied');
            },
          ),
        ],
      ]),
    );
  }
}
