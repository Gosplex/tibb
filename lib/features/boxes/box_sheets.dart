// Box switcher (design §9.10) and box editor (S6/S7).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/tibb_button.dart';
import '../locked/lock_service.dart';
import '../paywall/paywall_sheet.dart';
import '../../core/util/platform_copy.dart';

/// Returns the selected box id, or null if dismissed.
Future<String?> showBoxSwitcher(BuildContext context, {required String currentBoxId}) {
  return showTibbSheet<String>(context, builder: (_) => _BoxSwitcher(currentBoxId: currentBoxId));
}

class _BoxSwitcher extends StatelessWidget {
  const _BoxSwitcher({required this.currentBoxId});
  final String currentBoxId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s.repo, s.settings]),
      builder: (context, _) {
        final boxes = s.repo.boxes();
        final c = context.colors;
        return SheetScaffold(
          title: 'Boxes',
          child: Column(children: [
            for (final b in boxes)
              _BoxRow(
                box: b,
                selected: b.id == currentBoxId,
                hideCount: s.settings.hideUnreviewedCounts,
                onTap: () => Navigator.of(context).pop(b.id),
                onEdit: () => showBoxEditor(context, existing: b),
              ),
            const SizedBox(height: Space.s200),
            InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () async {
                if (boxes.isNotEmpty && !await ensurePro(context, PaywallReason.secondBox)) return;
                if (!context.mounted) return;
                final created = await showBoxEditor(context);
                if (created != null && context.mounted) Navigator.of(context).pop(created);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s200),
                child: Row(children: [
                  Container(
                    width: Sizes.boxTile,
                    height: Sizes.boxTile,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: c.borderDefault),
                    ),
                    child: Icon(TibbIcons.plus, color: c.textSecondary),
                  ),
                  const SizedBox(width: Space.s300),
                  Text('New box', style: context.type.titleXs),
                  const Spacer(),
                  if (!s.pro.isPro && boxes.isNotEmpty)
                    TibbTag(label: 'Pro', fg: c.textAccent, bg: c.highlight),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _BoxRow extends StatelessWidget {
  const _BoxRow({required this.box, required this.selected, required this.hideCount, required this.onTap, required this.onEdit});
  final Box box;
  final bool selected;
  final bool hideCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final preview = box.locked ? 'Locked' : (box.lastPreview ?? 'Empty');
    return Semantics(
      selected: selected,
      label: '${box.name}${box.locked ? ', locked' : ''}'
          '${box.unreviewedCount > 0 ? ', ${box.unreviewedCount} unreviewed' : ''}',
      child: InkWell(
        onTap: onTap,
        onLongPress: onEdit,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Space.s200, horizontal: Space.s200),
          decoration: BoxDecoration(
            color: selected ? c.highlight : null,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(children: [
            BoxTile(box: box),
            const SizedBox(width: Space.s300),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(box.name, style: context.type.titleXs, overflow: TextOverflow.ellipsis)),
                  if (box.locked) ...[
                    const SizedBox(width: Space.s100),
                    Icon(TibbIcons.lockFill, size: 14, color: c.privateFg),
                  ],
                ]),
                Text(preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodySm.copyWith(color: box.locked ? c.privateFg : c.textSecondary)),
              ]),
            ),
            if (!hideCount && box.unreviewedCount > 0 && !box.locked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.s200, vertical: Space.s050),
                decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.full)),
                child: Text('${box.unreviewedCount}', style: context.type.labelMd.copyWith(color: c.textSecondary)),
              ),
            TibbIconButton(icon: TibbIcons.edit, label: 'Edit ${box.name}', onPressed: onEdit),
          ]),
        ),
      ),
    );
  }
}

const _emojis = [
  '📦', '💼', '🏠', '🧾', '🍳', '📚', '💡', '✈️', '🎵', '📸', '🛒', '💪',
  '🎓', '🩺', '💰', '🔑', '🎁', '🌱', '🎨', '🧠', '📝', '🔒', '❤️', '⭐',
];

/// Create (existing == null) or edit a box. Returns the box id on save.
Future<String?> showBoxEditor(BuildContext context, {Box? existing}) =>
    showTibbSheet<String>(context, builder: (_) => _BoxEditor(existing: existing));

class _BoxEditor extends StatefulWidget {
  const _BoxEditor({this.existing});
  final Box? existing;

  @override
  State<_BoxEditor> createState() => _BoxEditorState();
}

class _BoxEditorState extends State<_BoxEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _emoji = widget.existing?.emoji ?? '💼';
  late BoxAccent _accent = BoxAccent.fromName(widget.existing?.color ?? 'ocean');
  late bool _locked = widget.existing?.locked ?? false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _toggleLock(bool value) async {
    final s = AppScope.of(context);
    if (value && !await ensurePro(context, PaywallReason.lock)) return;
    if (!mounted) return;
    // Changing a lock always requires authentication, in both directions.
    final r = await s.locks.authenticate(value ? 'Lock this box' : 'Remove the lock');
    if (!mounted) return;
    if (r == UnlockResult.success) {
      HapticFeedback.selectionClick();
      setState(() => _locked = value);
    } else if (r == UnlockResult.unavailable) {
      showToast(context, 'Set a screen lock on this phone to use locked boxes.');
    }
  }

  void _save() {
    final repo = AppScope.of(context).repo;
    final name = _name.text.trim().isEmpty ? 'Untitled box' : _name.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      final b = repo.createBox(name: name, emoji: _emoji, color: _accent.name);
      if (_locked) repo.updateBox(b.id, locked: true);
      Navigator.of(context).pop(b.id);
    } else {
      repo.updateBox(existing.id, name: name, emoji: _emoji, color: _accent.name, locked: _locked);
      Navigator.of(context).pop(existing.id);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final repo = AppScope.of(context).repo;
    if (repo.boxes().length <= 1) {
      showToast(context, 'You need at least one box.');
      return;
    }
    final count = repo.items(existing.id).length + repo.items(existing.id, archived: true).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${existing.name}?'),
        content: Text(count == 0
            ? 'This box is empty.'
            : 'This deletes the $count item${count == 1 ? '' : 's'} inside it from this phone. Export first if you want a copy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep box')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete box', style: TextStyle(color: ctx.colors.errorFg)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    repo.deleteBox(existing.id);
    Navigator.of(context).pop(repo.defaultBoxId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return SheetScaffold(
      title: widget.existing == null ? 'New box' : 'Edit box',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _name,
          autofocus: widget.existing == null,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          style: t.input,
          decoration: const InputDecoration(labelText: 'Box name', hintText: 'Work, Recipes, Receipts…', counterText: ''),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: Space.s600),
        Text('Emoji', style: t.labelMd.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.s200),
        Wrap(spacing: Space.s200, runSpacing: Space.s200, children: [
          for (final e in _emojis)
            Semantics(
              selected: e == _emoji,
              button: true,
              label: 'Emoji $e',
              child: GestureDetector(
                onTap: () => setState(() => _emoji = e),
                child: AnimatedContainer(
                  duration: context.motion(Motion.fast),
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e == _emoji ? c.highlight : c.surfaceSunken,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: e == _emoji ? Border.all(color: c.borderSelected, width: 2) : null,
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: Space.s600),
        Text('Color', style: t.labelMd.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.s200),
        Wrap(spacing: Space.s300, runSpacing: Space.s300, children: [
          for (final a in BoxAccent.values)
            Semantics(
              selected: a == _accent,
              button: true,
              label: 'Color ${a.name}',
              child: GestureDetector(
                onTap: () => setState(() => _accent = a),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: a.resolve(c.brightness),
                    shape: BoxShape.circle,
                    border: a == _accent ? Border.all(color: c.textPrimary, width: 3) : null,
                  ),
                  child: a == _accent ? Icon(TibbIcons.check, size: 16, color: c.surface) : null,
                ),
              ),
            ),
        ]),
        const SizedBox(height: Space.s600),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.s400, vertical: Space.s200),
          decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.lg)),
          child: Row(children: [
            Icon(TibbIcons.lock, color: c.privateFg),
            const SizedBox(width: Space.s300),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Lock this box', style: t.bodyMd),
                Text('Needs ${PlatformCopy.unlockMethod} to open.', style: t.bodySm.copyWith(color: c.textTertiary)),
              ]),
            ),
            Switch(value: _locked, onChanged: _toggleLock),
          ]),
        ),
        const SizedBox(height: Space.s600),
        TibbButton(label: widget.existing == null ? 'Create box' : 'Save', onPressed: _save),
        if (widget.existing != null) ...[
          const SizedBox(height: Space.s200),
          TibbButton(label: 'Delete box', variant: TibbButtonVariant.ghost, onPressed: _delete),
        ],
      ]),
    );
  }
}
