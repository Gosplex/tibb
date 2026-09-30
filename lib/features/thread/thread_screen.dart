// The thread (design S2): one box, newest at the bottom, composer always
// present. This is the home screen — there is no dashboard in front of it.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/models.dart';
import '../../core/platform/tibb_platform.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/illustrations.dart';
import '../../design/widgets/tibb_button.dart';
import '../archive/archive_screen.dart';
import '../boxes/box_sheets.dart';
import '../bridge/bridge_sheet.dart';
import '../items/item_actions.dart';
import '../locked/lock_gate.dart';
import '../paywall/paywall_sheet.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../share_in/share_in_sheet.dart';
import '../whatsapp_import/whatsapp_import_screen.dart';
import 'bubble.dart';
import 'composer.dart';

class ThreadScreen extends StatefulWidget {
  const ThreadScreen({super.key});

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  late String _boxId;
  bool _initialized = false;

  /// Items unreviewed when this box was opened: they keep their dot for this visit.
  Set<String> _unreviewedAtOpen = {};
  String? _dividerAboveId;

  /// Items that arrived while the screen is open (animate in once).
  final Set<String> _fresh = {};
  StreamSubscription<ChangeEvent>? _sub;
  StreamSubscription<SharePayload>? _shareSub;
  bool _handlingShare = false;
  Timer? _arrivalTimer;
  final Map<String, int> _arrivals = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final s = AppScope.of(context);
    _openBox(s.repo.defaultBoxId);
    _sub = s.repo.changes.listen(_onChange);
    // Share-into-Tibb (brief §7.2): shares while running, and the one that
    // cold-started the app.
    _shareSub = TibbPlatform.instance.shares.listen(_onShare);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await TibbPlatform.instance.takeInitialShare();
      if (initial != null) await _onShare(initial);
    });
  }

  Future<void> _onShare(SharePayload p) async {
    if (!mounted || _handlingShare) return;
    _handlingShare = true;
    try {
      final hasText = (p.text ?? '').trim().isNotEmpty;
      final single = p.files.length == 1 && !hasText ? p.files.first : null;
      if (single != null && single.looksLikeWhatsAppExport) {
        // A WhatsApp export goes straight to import, not into a box as a zip.
        final boxId = await Navigator.of(context).push<String>(MaterialPageRoute(
          builder: (_) => WhatsAppImportScreen(initialFile: File(single.path), initialName: single.name),
        ));
        if (boxId != null && mounted) setState(() => _openBox(boxId));
        return;
      }
      final saved = await showShareInSheet(context, p);
      if (saved && mounted) {
        setState(() {});
        // Back to the app the user shared from (design J2).
        await TibbPlatform.instance.moveToBack();
      }
    } finally {
      _handlingShare = false;
    }
  }

  Future<void> _openWhatsAppImport() async {
    final boxId = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const WhatsAppImportScreen()));
    if (boxId != null && mounted) setState(() => _openBox(boxId));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _shareSub?.cancel();
    _arrivalTimer?.cancel();
    super.dispose();
  }

  void _openBox(String boxId) {
    final s = AppScope.of(context);
    _boxId = boxId;
    s.repo.setMeta('default_box', boxId);
    final box = s.repo.box(boxId);
    final visible = box != null && (!box.locked || s.locks.isUnlocked(boxId));
    if (!visible) {
      _unreviewedAtOpen = {};
      _dividerAboveId = null;
      return;
    }
    final items = s.repo.items(boxId);
    final unreviewed = items.where((i) => !i.reviewed).toList();
    _unreviewedAtOpen = {for (final i in unreviewed) i.id};
    // Divider only when there's something older to separate from.
    _dividerAboveId = unreviewed.isNotEmpty && unreviewed.length < items.length
        ? (unreviewed..sort((a, b) => a.createdAt.compareTo(b.createdAt))).first.id
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) => s.repo.markBoxReviewed(boxId));
  }

  void _onChange(ChangeEvent e) {
    if (e.op != Ops.itemCreate || !mounted) return;
    final s = AppScope.of(context);
    _fresh.add(e.entityId);
    Future<void>.delayed(const Duration(seconds: 1), () => _fresh.remove(e.entityId));
    final boxId = e.payload['boxId'];
    if (boxId == _boxId) {
      // Arriving in the open box counts as reviewed — the user is looking at it.
      WidgetsBinding.instance.addPostFrameCallback((_) => s.repo.markBoxReviewed(_boxId));
    }
    if (s.repo.isThisDevice(e.deviceId)) return;
    // Batch arrivals from a computer into one toast (design §9.9 / §13.5).
    final name = s.repo.deviceNameFor(e.deviceId);
    _arrivals[name] = (_arrivals[name] ?? 0) + 1;
    _arrivalTimer?.cancel();
    _arrivalTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final parts = _arrivals.entries.map((a) => a.value == 1 ? 'Saved from ${a.key}' : '${a.value} items from ${a.key}');
      // No haptic: arrivals are passive events (design §11.2).
      showToast(context, parts.join(' · '));
      _arrivals.clear();
    });
  }

  void _afterSave() {
    final repo = AppScope.of(context).repo;
    final n = repo.incrementCounter('saves_count');
    if (n == 1 && !repo.flag('privacy_toast_shown')) {
      repo.setFlag('privacy_toast_shown');
      showToast(context, 'Saved on this phone. Nothing left it.');
    } else if (n == 2 && Platform.isAndroid && !repo.flag('share_hint_shown')) {
      // One hint at a time, each shown once (design §13.3).
      repo.setFlag('share_hint_shown');
      showToast(context, 'Next time, share into Tibb from any app — look for Tibb in the share sheet.');
    }
    if (n >= 15 && !repo.flag('soft_prompt_eligible')) {
      repo.setFlag('soft_prompt_eligible');
      setState(() {});
    }
  }

  Future<void> _switchBox() async {
    final id = await showBoxSwitcher(context, currentBoxId: _boxId);
    if (id != null && mounted) setState(() => _openBox(id));
  }

  Future<void> _openSearch() async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const SearchScreen()));
    if (id != null && mounted) setState(() => _openBox(id));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      // Bridge ticks every second while showing a code, so it's listened to
      // separately (icon + banner) instead of rebuilding the whole thread.
      listenable: Listenable.merge([s.repo, s.locks, s.pro, s.settings]),
      builder: (context, _) {
        var box = s.repo.box(_boxId);
        if (box == null) {
          // The open box was deleted (maybe from another sheet): fall back.
          _boxId = s.repo.defaultBoxId;
          box = s.repo.box(_boxId)!;
        }
        final locked = box.locked && !s.locks.isUnlocked(box.id);
        return Scaffold(
          appBar: _appBar(context, box),
          body: Listener(
            onPointerDown: (_) => s.locks.touch(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Sizes.threadMaxWidthTablet),
                child: Column(children: [
                  ..._banners(context),
                  if (locked)
                    Expanded(child: LockGate(key: ValueKey('gate-${box.id}'), box: box))
                  else ...[
                    _ClipboardCard(item: s.repo.latestClipboard()),
                    Expanded(child: _thread(context, box)),
                    Composer(boxId: box.id, onSaved: _afterSave),
                  ],
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, Box box) {
    final s = AppScope.of(context);
    final c = context.colors;
    final totalUnreviewed = s.repo.boxes().where((b) => b.id != box.id && !b.locked).fold<int>(0, (a, b) => a + b.unreviewedCount);
    return AppBar(
      titleSpacing: Space.s200,
      title: Semantics(
        button: true,
        label: 'Box: ${box.name}. Switch box',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: _switchBox,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s100, horizontal: Space.s100),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              BoxTile(box: box, size: 32),
              const SizedBox(width: Space.s200),
              Flexible(child: Text(box.name, style: context.type.titleMd, overflow: TextOverflow.ellipsis)),
              if (box.locked) ...[
                const SizedBox(width: Space.s100),
                Icon(TibbIcons.lockFill, size: 16, color: c.privateFg),
              ],
              const SizedBox(width: Space.s100),
              Icon(TibbIcons.caretDown, size: 16, color: c.textSecondary),
              if (totalUnreviewed > 0 && !s.settings.hideUnreviewedCounts) ...[
                const SizedBox(width: Space.s200),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: c.unreviewedDot, shape: BoxShape.circle),
                ),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TibbIconButton(icon: TibbIcons.search, label: 'Search', onPressed: _openSearch),
        ListenableBuilder(
          listenable: s.bridge,
          builder: (context, _) => TibbIconButton(
            icon: s.bridge.isConnected ? TibbIcons.bridgeFill : TibbIcons.bridge,
            label: s.bridge.isConnected ? 'Computer connected' : 'Open on computer',
            badge: s.bridge.isConnected,
            color: s.bridge.isConnected ? c.connectedFg : null,
            onPressed: () => openBridge(context),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: Icon(TibbIcons.more, color: c.textPrimary),
          color: c.surfaceOverlay,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
          onSelected: (v) async {
            switch (v) {
              case 'archive':
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ArchiveScreen(boxId: box.id)));
              case 'edit':
                await showBoxEditor(context, existing: box);
              case 'triage':
                final n = s.repo.archiveOlderThan(box.id, DateTime.now().subtract(const Duration(days: 30)));
                if (context.mounted) {
                  showToast(context, n == 0 ? 'Nothing older than 30 days.' : 'Archived $n item${n == 1 ? '' : 's'}',
                      actionLabel: n == 0 ? null : 'Undo', onAction: () => s.repo.unarchiveAll(box.id));
                }
              case 'whatsapp':
                await _openWhatsAppImport();
              case 'settings':
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
            }
          },
          itemBuilder: (_) => [
            _menuItem('archive', TibbIcons.archive, 'Archive'),
            _menuItem('triage', TibbIcons.archiveAction, 'Archive older than 30 days'),
            _menuItem('edit', TibbIcons.edit, 'Edit box'),
            _menuItem('whatsapp', TibbIcons.chat, 'Import from WhatsApp'),
            _menuItem('settings', TibbIcons.settings, 'Settings'),
          ],
        ),
        const SizedBox(width: Space.s100),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) => PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 20, color: context.colors.textSecondary),
          const SizedBox(width: Space.s300),
          Text(label, style: context.type.bodyMd),
        ]),
      );

  List<Widget> _banners(BuildContext context) {
    final s = AppScope.of(context);
    final banners = <Widget>[];
    banners.add(ListenableBuilder(
      listenable: s.bridge,
      builder: (context, _) {
        final session = s.bridge.session;
        if (session == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.s400, Space.s200, Space.s400, 0),
          child: GestureDetector(
            onTap: () => openBridge(context),
            child: Semantics(
              button: true,
              child: InfoCard(
                tone: InfoTone.connected,
                title: '${session.deviceName} is connected',
                body: Platform.isIOS
                    ? 'Keep Tibb open while you use your computer. Tap to stop.'
                    : 'Tap to send your clipboard or stop Bridge.',
              ),
            ),
          ),
        );
      },
    ));
    if (!s.pro.isPro && s.repo.flag('soft_prompt_eligible') && !s.repo.flag('soft_prompt_dismissed')) {
      banners.add(Padding(
        padding: const EdgeInsets.fromLTRB(Space.s400, Space.s200, Space.s400, 0),
        child: InfoCard(
          tone: InfoTone.info,
          icon: TibbIcons.pro,
          title: 'Enjoying Tibb?',
          body: 'Pro adds photos, files and your computer.',
          action: Row(children: [
            TibbButton(
              label: 'See Pro',
              size: TibbButtonSize.sm,
              expand: false,
              onPressed: () => ensurePro(context, PaywallReason.soft),
            ),
            const SizedBox(width: Space.s200),
            TibbButton(
              label: 'Not now',
              size: TibbButtonSize.sm,
              variant: TibbButtonVariant.ghost,
              expand: false,
              onPressed: () {
                s.repo.setFlag('soft_prompt_dismissed'); // shown once, never nags (brief §9.3)
                setState(() {});
              },
            ),
          ]),
        ),
      ));
    }
    return banners;
  }

  Widget _thread(BuildContext context, Box box) {
    final s = AppScope.of(context);
    final items = s.repo.items(box.id)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (items.isEmpty) {
      final firstBox = s.repo.boxes().length == 1;
      return SingleChildScrollView(
        child: EmptyState(
          art: const TibbIllustration(Illustration.openBox),
          headline: 'Your box is ready.',
          body: Platform.isAndroid
              ? 'Save anything here — or share into Tibb from any app. It stays on this phone.'
              : 'Type below, tap + for photos and files, or hold the mic for a voice memo. It stays on this phone.',
          action: firstBox
              ? TibbButton(
                  label: 'Coming from WhatsApp?',
                  icon: TibbIcons.chat,
                  variant: TibbButtonVariant.ghost,
                  size: TibbButtonSize.md,
                  expand: false,
                  onPressed: _openWhatsAppImport,
                )
              : null,
        ),
      );
    }

    final pinned = items.where((i) => i.pinned).toList();
    final entries = <_Entry>[];
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    bool sameGroup(Item a, Item b) =>
        a.originDeviceId == b.originDeviceId &&
        sameDay(a.createdAt, b.createdAt) &&
        a.createdAt.difference(b.createdAt).inMinutes.abs() < 2;

    // Built newest → oldest because the ListView is reversed (newest at bottom).
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final newer = i > 0 ? items[i - 1] : null;
      final older = i + 1 < items.length ? items[i + 1] : null;
      final isSelf = s.repo.isThisDevice(item.originDeviceId);
      entries.add(_Entry.item(item, isSelf: isSelf, tail: newer == null || !sameGroup(item, newer)));
      if (!isSelf && (older == null || !sameGroup(older, item))) {
        entries.add(_Entry.origin(item.originDeviceName ?? 'Another device'));
      }
      if (item.id == _dividerAboveId) entries.add(const _Entry.divider());
      if (older == null || !sameDay(older.createdAt, item.createdAt)) {
        entries.add(_Entry.day(formatDay(item.createdAt)));
      }
    }
    if (pinned.isNotEmpty) entries.add(_Entry.pinned(pinned));

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(Space.s400, Space.s200, Space.s400, Space.s300),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        switch (e.kind) {
          case _Kind.day:
            return _DaySeparator(label: e.label!);
          case _Kind.origin:
            return _OriginLabel(label: e.label!);
          case _Kind.divider:
            return const _NewDivider();
          case _Kind.pinned:
            return _PinnedStrip(items: e.pinned!);
          case _Kind.item:
            final item = e.item!;
            return Padding(
              padding: EdgeInsets.only(top: e.tail ? Space.s200 : Space.s050),
              child: _Swipeable(
                item: item,
                child: Bubble(
                  key: ValueKey(item.id),
                  item: item,
                  isSelf: e.isSelf,
                  tail: e.tail,
                  showUnreviewedDot: _unreviewedAtOpen.contains(item.id),
                  animateIn: _fresh.contains(item.id),
                  onLongPress: () => showItemActions(context, item),
                ),
              ),
            );
        }
      },
    );
  }
}

enum _Kind { item, day, origin, divider, pinned }

class _Entry {
  const _Entry._(this.kind, {this.item, this.label, this.isSelf = false, this.tail = false, this.pinned});
  const _Entry.item(Item item, {required bool isSelf, required bool tail})
      : this._(_Kind.item, item: item, isSelf: isSelf, tail: tail);
  const _Entry.day(String label) : this._(_Kind.day, label: label);
  const _Entry.origin(String label) : this._(_Kind.origin, label: label);
  const _Entry.divider() : this._(_Kind.divider);
  const _Entry.pinned(List<Item> items) : this._(_Kind.pinned, pinned: items);

  final _Kind kind;
  final Item? item;
  final String? label;
  final bool isSelf;
  final bool tail;
  final List<Item>? pinned;
}

/// Swipe left = archive, swipe right = pin (design §9.3 behavior).
class _Swipeable extends StatelessWidget {
  const _Swipeable({required this.item, required this.child});
  final Item item;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repo;
    final c = context.colors;
    Widget bg(Alignment align, IconData icon, String label, Color color) => Container(
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: Space.s600),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color),
            const SizedBox(width: Space.s200),
            Text(label, style: context.type.labelMd.copyWith(color: color)),
          ]),
        );
    return Dismissible(
      key: ValueKey('swipe-${item.id}'),
      dismissThresholds: const {DismissDirection.endToStart: 0.35, DismissDirection.startToEnd: 0.3},
      background: bg(Alignment.centerLeft, item.pinned ? TibbIcons.pin : TibbIcons.pinFill,
          item.pinned ? 'Unpin' : 'Pin', c.textAccent),
      secondaryBackground: bg(Alignment.centerRight, TibbIcons.archiveAction, 'Archive', c.textSecondary),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.selectionClick();
          repo.updateItem(item.id, pinned: !item.pinned);
          return false; // pin keeps the bubble in place
        }
        return true;
      },
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        repo.updateItem(item.id, archived: true);
        showToast(context, 'Archived', actionLabel: 'Undo', onAction: () => repo.updateItem(item.id, archived: false));
      },
      child: child,
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s400),
      child: Center(
        child: Semantics(
          header: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.s300, vertical: Space.s150),
            decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.full)),
            child: Text(label, style: context.type.caption.copyWith(color: c.textSecondary)),
          ),
        ),
      ),
    );
  }
}

class _OriginLabel extends StatelessWidget {
  const _OriginLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: Space.s100, top: Space.s300, bottom: Space.s050),
      child: Row(children: [
        Icon(TibbIcons.fromComputer, size: 14, color: c.textTertiary),
        const SizedBox(width: Space.s100),
        Text(label, style: context.type.caption.copyWith(color: c.textTertiary)),
      ]),
    );
  }
}

class _NewDivider extends StatelessWidget {
  const _NewDivider();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s300),
      child: Row(children: [
        Expanded(child: Divider(color: c.borderSubtle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s200),
          child: Text('New since you last looked', style: context.type.caption.copyWith(color: c.textAccent)),
        ),
        Expanded(child: Divider(color: c.borderSubtle)),
      ]),
    );
  }
}

class _PinnedStrip extends StatelessWidget {
  const _PinnedStrip({required this.items});
  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s200, bottom: Space.s200),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => showTibbSheet<void>(context, builder: (ctx) => SheetScaffold(
              title: 'Pinned',
              child: Column(children: [
                for (final i in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(TibbIcons.pinFill, color: c.textAccent),
                    title: Text(i.preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: ctx.type.bodyMd),
                    subtitle: Text(formatDay(i.createdAt), style: ctx.type.caption.copyWith(color: c.textTertiary)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showItemActions(context, i);
                    },
                  ),
              ]),
            )),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.s300, vertical: Space.s200),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.borderSubtle)),
          child: Row(children: [
            Icon(TibbIcons.pinFill, size: 16, color: c.textAccent),
            const SizedBox(width: Space.s200),
            Expanded(
              child: Text(items.length == 1 ? items.first.preview : '${items.length} pinned · ${items.first.preview}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.bodySm),
            ),
            Icon(TibbIcons.caretRight, size: 14, color: c.textTertiary),
          ]),
        ),
      ),
    );
  }
}

/// The clipboard card (design §9.13): the newest clipboard item from either
/// side of the Bridge, pinned above the thread until it expires (24 h).
class _ClipboardCard extends StatelessWidget {
  const _ClipboardCard({required this.item});
  final Item? item;

  @override
  Widget build(BuildContext context) {
    final i = item;
    if (i == null) return const SizedBox.shrink();
    final c = context.colors;
    final repo = AppScope.of(context).repo;
    final from = repo.isThisDevice(i.originDeviceId) ? 'this phone' : (i.originDeviceName ?? 'a computer');
    final left = i.expiresAt?.difference(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s400, Space.s200, Space.s400, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.s400, Space.s300, Space.s200, Space.s300),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.borderDefault, width: 1.5),
        ),
        child: Row(children: [
          Icon(TibbIcons.clipboard, color: c.textSecondary),
          const SizedBox(width: Space.s300),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Clipboard from $from${left == null ? '' : ' · clears in ${left.inHours}h'}',
                  style: context.type.caption.copyWith(color: c.textTertiary)),
              const SizedBox(height: Space.s050),
              Text(i.text ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.monoMd),
            ]),
          ),
          TibbButton(
            label: 'Copy',
            size: TibbButtonSize.sm,
            expand: false,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: i.text ?? ''));
              HapticFeedback.selectionClick();
              if (context.mounted) showToast(context, 'Copied');
            },
          ),
          TibbIconButton(icon: TibbIcons.close, label: 'Clear clipboard card', onPressed: () => repo.deleteItem(i.id)),
        ]),
      ),
    );
  }
}
