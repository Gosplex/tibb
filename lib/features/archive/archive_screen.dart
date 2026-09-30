import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../items/item_actions.dart';

/// Archived items of one box (design S9). Archive is "done", not "gone":
/// swipe or tap to move an item back.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key, required this.boxId});
  final String boxId;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repo;
    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final c = context.colors;
          final items = repo.items(boxId, archived: true)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (items.isEmpty) {
            return EmptyState(
              art: Icon(TibbIcons.archive, size: 64, color: c.textTertiary),
              headline: 'Nothing archived',
              body: 'Swipe left on anything you’re done with. It moves here — still searchable, never deleted.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(Space.s400),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: Space.s200),
            itemBuilder: (context, i) {
              final item = items[i];
              return Dismissible(
                key: ValueKey('arch-${item.id}'),
                direction: DismissDirection.startToEnd,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: Space.s600),
                  child: Row(children: [
                    Icon(TibbIcons.unarchive, color: c.textAccent),
                    const SizedBox(width: Space.s200),
                    Text('Move back', style: context.type.labelMd.copyWith(color: c.textAccent)),
                  ]),
                ),
                onDismissed: (_) {
                  repo.updateItem(item.id, archived: false);
                  showToast(context, 'Moved back', actionLabel: 'Undo', onAction: () => repo.updateItem(item.id, archived: true));
                },
                child: Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
                    title: Text(item.preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.bodyMd),
                    subtitle: Text('${formatDay(item.createdAt)} · ${formatTime(item.createdAt)}',
                        style: context.type.caption.copyWith(color: c.textTertiary)),
                    onTap: () => showItemActions(context, item),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
