// Item actions (design §9.11): long-press a bubble. Pin / archive / note /
// move / copy / share / edit / delete. Delete is last, destructive, with undo.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/tibb_button.dart';
import 'item_viewers.dart';

Future<void> showItemActions(BuildContext context, Item item) async {
  HapticFeedback.mediumImpact();
  final repo = AppScope.of(context).repo;
  final isText = item.type == ItemType.text || item.type == ItemType.link || item.type == ItemType.clipboard;

  final action = await showTibbSheet<String>(context, builder: (ctx) {
    Widget row(String id, IconData icon, String label, {bool destructive = false}) =>
        TibbRow(icon: icon, title: label, destructive: destructive, onTap: () => Navigator.of(ctx).pop(id), trailing: const SizedBox());
    return SheetScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s300),
          child: Text(item.preview, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: ctx.type.bodyMd.copyWith(color: ctx.colors.textSecondary)),
        ),
        ListGroup(children: [
          if (isText) row('copy', TibbIcons.copy, 'Copy'),
          if (!isText) row('share', TibbIcons.exportIcon, 'Share or open in…'),
          row('pin', item.pinned ? TibbIcons.pinFill : TibbIcons.pin, item.pinned ? 'Unpin' : 'Pin to top'),
          row('note', TibbIcons.note, item.note == null ? 'Add a note' : 'Edit note'),
          row('move', TibbIcons.box, 'Move to box…'),
          if (item.type == ItemType.text) row('edit', TibbIcons.edit, 'Edit text'),
          row('archive', item.archived ? TibbIcons.unarchive : TibbIcons.archiveAction,
              item.archived ? 'Move back to box' : 'Archive'),
        ]),
        const SizedBox(height: Space.s300),
        ListGroup(children: [row('delete', TibbIcons.trash, 'Delete', destructive: true)]),
      ]),
    );
  });
  if (action == null || !context.mounted) return;

  switch (action) {
    case 'copy':
      await Clipboard.setData(ClipboardData(text: item.text ?? ''));
      if (context.mounted) showToast(context, 'Copied');
    case 'share':
      await openFileExternally(context, item);
    case 'pin':
      repo.updateItem(item.id, pinned: !item.pinned);
    case 'note':
      final note = await _editText(context, title: item.note == null ? 'Add a note' : 'Edit note',
          initial: item.note ?? '', hint: 'What is this for?');
      if (note != null) repo.updateItem(item.id, note: note);
    case 'edit':
      final text = await _editText(context, title: 'Edit text', initial: item.text ?? '', hint: '');
      if (text != null && text.trim().isNotEmpty) repo.updateItem(item.id, text: text.trim());
    case 'move':
      final boxes = repo.boxes().where((b) => b.id != item.boxId).toList();
      if (boxes.isEmpty) {
        showToast(context, 'Make another box first.');
        return;
      }
      final target = await showTibbSheet<String>(context, builder: (ctx) => SheetScaffold(
            title: 'Move to',
            child: Column(children: [
              for (final b in boxes)
                ListTile(
                  leading: BoxTile(box: b),
                  title: Text(b.name, style: ctx.type.titleXs),
                  onTap: () => Navigator.of(ctx).pop(b.id),
                ),
            ]),
          ));
      if (target != null) {
        repo.updateItem(item.id, boxId: target);
        if (context.mounted) showToast(context, 'Moved to ${repo.box(target)?.name ?? 'box'}');
      }
    case 'archive':
      repo.updateItem(item.id, archived: !item.archived);
      if (context.mounted) {
        showToast(context, item.archived ? 'Moved back' : 'Archived',
            actionLabel: 'Undo', onAction: () => repo.updateItem(item.id, archived: item.archived));
      }
    case 'delete':
      repo.deleteItem(item.id);
      if (context.mounted) {
        showToast(context, 'Deleted', actionLabel: 'Undo', onAction: () => repo.restoreItem(item.id));
      }
  }
}

Future<String?> _editText(BuildContext context, {required String title, required String initial, required String hint}) {
  final controller = TextEditingController(text: initial);
  return showTibbSheet<String>(context, builder: (ctx) => SheetScaffold(
        title: title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            style: ctx.type.input,
            decoration: InputDecoration(hintText: hint),
          ),
          const SizedBox(height: Space.s400),
          TibbButton(label: 'Save', onPressed: () => Navigator.of(ctx).pop(controller.text)),
        ]),
      )).whenComplete(() {
    // Dispose after the sheet's exit animation so the field never sees a dead controller.
    Future<void>.delayed(const Duration(milliseconds: 500), controller.dispose);
  });
}
