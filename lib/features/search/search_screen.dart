import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/repository/library_repository.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../items/item_actions.dart';

/// Search across every unlocked box (design S8). Returns a box id when the
/// user picks "Show in box".
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  SearchFilter _filter = SearchFilter.all;
  List<SearchResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _run() {
    final s = AppScope.of(context);
    setState(() {
      _results = s.repo.search(_controller.text, filter: _filter, unlockedBoxIds: s.locks.unlockedBoxIds);
    });
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _run);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final query = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: t.input,
          decoration: InputDecoration(
            hintText: 'Search everything',
            prefixIcon: Icon(TibbIcons.search, color: c.textTertiary),
            filled: true,
            fillColor: c.surfaceSunken,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.full), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.full), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.full), borderSide: BorderSide.none),
          ),
        ),
        actions: const [SizedBox(width: Space.s400)],
      ),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.s400),
            children: [
              for (final f in SearchFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: Space.s200),
                  child: ChoiceChip(
                    label: Text(switch (f) {
                      SearchFilter.all => 'All',
                      SearchFilter.text => 'Text',
                      SearchFilter.links => 'Links',
                      SearchFilter.media => 'Photos & videos',
                      SearchFilter.files => 'Files',
                      SearchFilter.voice => 'Voice',
                    }),
                    selected: _filter == f,
                    showCheckmark: false,
                    selectedColor: c.actionSecondary,
                    backgroundColor: c.surfaceSunken,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    labelStyle: t.labelMd.copyWith(color: _filter == f ? c.onActionSecondary : c.textPrimary),
                    onSelected: (_) {
                      setState(() => _filter = f);
                      _run();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: query.isEmpty
              ? EmptyState(
                  art: Icon(TibbIcons.search, size: 56, color: c.textTertiary),
                  headline: 'Search everything',
                  body: 'Words in notes, messages and file names. Locked boxes are searched only while unlocked.',
                )
              : _results.isEmpty
                  ? EmptyState(
                      headline: 'Nothing matches “$query”',
                      body: 'Try fewer words or another filter.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(Space.s400),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final r = _results[i];
                        final header = i == 0 || _results[i - 1].box.id != r.box.id;
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (header)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.s400, bottom: Space.s200),
                              child: Row(children: [
                                BoxTile(box: r.box, size: 24),
                                const SizedBox(width: Space.s200),
                                Text(r.box.name, style: t.titleXs),
                              ]),
                            ),
                          Material(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(Radii.lg),
                            child: ListTile(
                              title: _Highlighted(text: r.item.preview + (r.item.note != null ? ' — ${r.item.note}' : ''), query: query),
                              subtitle: Text(
                                  '${formatDay(r.item.createdAt)}${r.item.archived ? ' · Archived' : ''}',
                                  style: t.caption.copyWith(color: c.textTertiary)),
                              trailing: TextButton(
                                onPressed: () => Navigator.of(context).pop(r.box.id),
                                child: Text('Show in box', style: t.labelMd.copyWith(color: c.textPrimary)),
                              ),
                              onTap: () => showItemActions(context, r.item).then((_) => _run()),
                            ),
                          ),
                          const SizedBox(height: Space.s200),
                        ]);
                      },
                    ),
        ),
      ]),
    );
  }
}

/// Matched words get a saffron.100 highlight (never color alone: also bold).
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.query});
  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = context.type.bodyMd;
    final terms = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (i < text.length) {
      var matchLen = 0;
      for (final term in terms) {
        if (lower.startsWith(term, i) && term.length > matchLen) matchLen = term.length;
      }
      if (matchLen > 0) {
        spans.add(TextSpan(
          text: text.substring(i, i + matchLen),
          style: TextStyle(backgroundColor: c.highlight, fontWeight: FontWeight.w700),
        ));
        i += matchLen;
      } else {
        spans.add(TextSpan(text: text[i]));
        i++;
      }
    }
    return Text.rich(TextSpan(style: base, children: spans), maxLines: 3, overflow: TextOverflow.ellipsis);
  }
}
