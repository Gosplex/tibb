import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/tibb_button.dart';
import 'lock_service.dart';
import '../../core/util/platform_copy.dart';

/// Shown instead of a locked box's thread (design §9.12). Content is absent,
/// never blurred, until Face ID / passcode succeeds.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.box});
  final Box box;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    // Prompt automatically on open (design S5).
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await AppScope.of(context).locks.unlock(widget.box.id, widget.box.name);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (r) {
        UnlockResult.success => null,
        UnlockResult.failed => "That didn't work. Try again.",
        UnlockResult.unavailable => 'Set a screen lock on this phone to use locked boxes.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.s600),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: c.privateBg, shape: BoxShape.circle),
            child: Icon(TibbIcons.lockFill, size: 40, color: c.privateFg),
          ),
          const SizedBox(height: Space.s600),
          Text('${widget.box.name} is locked', style: context.type.titleLg, textAlign: TextAlign.center),
          const SizedBox(height: Space.s200),
          Text('Use ${PlatformCopy.unlockMethod} to open it.',
              style: context.type.bodyMd.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
          if (_message != null) ...[
            const SizedBox(height: Space.s400),
            InfoCard(tone: InfoTone.warning, title: _message!),
          ],
          const SizedBox(height: Space.s600),
          TibbButton(label: 'Unlock', icon: TibbIcons.lockOpen, loading: _busy, onPressed: _unlock),
        ]),
      ),
    );
  }
}
