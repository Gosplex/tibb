// WhatsApp import (design S22 / journey J7):
//   instructions → pick or share the export → preview with a date-order check
//   → progress → done. Everything is read on this phone; nothing is uploaded.
//
// Free: messages and links. Pro: photos, videos, voice notes and files too.
// This is a creation gate — nothing already in Tibb is ever locked away.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/app_scope.dart';
import '../../core/util/format.dart';
import '../../core/util/platform_copy.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/illustrations.dart';
import '../../design/widgets/tibb_button.dart';
import '../paywall/paywall_sheet.dart';
import 'whatsapp_importer.dart';

class WhatsAppImportScreen extends StatefulWidget {
  const WhatsAppImportScreen({super.key, this.initialFile, this.initialName});

  /// An export shared straight into Tibb (Android share sheet / "Open with").
  final File? initialFile;
  final String? initialName;

  @override
  State<WhatsAppImportScreen> createState() => _WhatsAppImportScreenState();
}

enum _Step { intro, reading, preview, importing, done }

class _WhatsAppImportScreenState extends State<WhatsAppImportScreen> {
  _Step _step = _Step.intro;
  WaPrepared? _prepared;
  Set<String> _senders = {};
  String? _error;
  int _done = 0;
  int _total = 0;
  bool _includeMedia = true;
  bool _cancelled = false;
  bool _reparsing = false;
  WaImportSummary? _summary;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFile;
    if (f != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _read(f, widget.initialName));
    }
  }

  @override
  void dispose() {
    _prepared?.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any, withData: false);
    final file = picked?.files.single;
    if (file?.path == null) return;
    await _read(File(file!.path!), file.name);
  }

  Future<void> _read(File file, String? name) async {
    setState(() {
      _step = _Step.reading;
      _error = null;
    });
    try {
      final tmp = await getTemporaryDirectory();
      final prepared = await WhatsAppImporter.prepare(file, parent: tmp, displayName: name);
      if (!mounted) {
        await prepared.dispose();
        return;
      }
      await _prepared?.dispose();
      setState(() {
        _prepared = prepared;
        _senders = prepared.result.senders.toSet();
        _step = _Step.preview;
      });
    } on WaImportException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _step = _Step.intro;
        _error = e.message;
      });
    }
  }

  Future<void> _setDayFirst(bool v) async {
    final p = _prepared;
    if (p == null) return;
    setState(() => _reparsing = true);
    await p.setDayFirst(v);
    if (mounted) setState(() => _reparsing = false);
  }

  Future<void> _import() async {
    final s = AppScope.of(context);
    final prepared = _prepared!;
    final withMedia = _includeMedia && prepared.mediaAvailable > 0;
    if (withMedia && !await ensurePro(context, PaywallReason.whatsappMedia)) {
      if (mounted) setState(() => _includeMedia = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _step = _Step.importing;
      _done = 0;
      _total = 0;
      _cancelled = false;
    });
    try {
      final summary = await WhatsAppImporter(s.repo).run(
        prepared,
        senders: _senders,
        includeMedia: withMedia,
        isPro: s.pro.isPro,
        isCancelled: () => _cancelled,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
          });
        },
      );
      WhatsAppImporter.notifyIfBackground(summary.created);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _summary = summary;
        _step = _Step.done;
      });
    } on WaImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.preview;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _step == _Step.importing;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import from WhatsApp'),
          automaticallyImplyLeading: !busy,
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: context.motion(Motion.normal),
            switchInCurve: Motion.decelerate,
            child: switch (_step) {
              _Step.intro => _intro(context),
              _Step.reading => _reading(context),
              _Step.preview => _preview(context),
              _Step.importing => _importing(context),
              _Step.done => _doneView(context),
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- intro

  Widget _intro(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final ios = PlatformCopy.store == 'App Store';
    final steps = ios
        ? const [
            ('Open the chat', 'In WhatsApp, open the chat you message yourself in, then tap your name at the top.'),
            ('Export it', 'Tap Export Chat and choose Attach Media to bring photos and files too.'),
            ('Save, then pick it here', 'Choose Save to Files, then come back and pick the .zip.'),
          ]
        : const [
            ('Open the chat', 'In WhatsApp, open the chat you message yourself in.'),
            ('Export it', 'Tap ⋮ → More → Export chat, and choose Include media.'),
            ('Send it to Tibb', 'Pick Tibb in the share sheet — or save it and choose it below.'),
          ];
    return ListView(key: const ValueKey('intro'), padding: const EdgeInsets.all(Space.s600), children: [
      const Center(child: TibbIllustration(Illustration.chatToBox)),
      const SizedBox(height: Space.s600),
      Text('Bring your notes-to-self over', style: t.headlineHero, textAlign: TextAlign.center),
      const SizedBox(height: Space.s200),
      Text('Years of saves, in one step. Everything is read on this phone — nothing is uploaded.',
          style: t.bodyMd.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: Space.s800),
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s300),
          child: _NumberedCard(number: i + 1, title: steps[i].$1, body: steps[i].$2),
        ),
      if (_error != null) ...[
        const SizedBox(height: Space.s300),
        InfoCard(tone: InfoTone.error, title: "That file didn't work", body: _error),
      ],
      const SizedBox(height: Space.s600),
      TibbButton(label: 'Choose the export', icon: TibbIcons.importIcon, onPressed: _pick),
      const SizedBox(height: Space.s300),
      Text('On a computer? Open Tibb Bridge and drop the .zip there.',
          textAlign: TextAlign.center, style: t.bodySm.copyWith(color: c.textTertiary)),
    ]);
  }

  Widget _reading(BuildContext context) => Center(
        key: const ValueKey('reading'),
        child: Padding(
          padding: const EdgeInsets.all(Space.s600),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const TibbIllustration(Illustration.chatToBox, width: 140),
            const SizedBox(height: Space.s600),
            Text('Reading your export…', style: context.type.titleMd),
            const SizedBox(height: Space.s400),
            const SizedBox(width: 200, child: TibbProgress(value: null)),
          ]),
        ),
      );

  // -------------------------------------------------------------- preview

  Widget _preview(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final prepared = _prepared!;
    final r = prepared.result;
    final pro = AppScope.of(context).pro.isPro;
    final first = r.messages.first.time;
    final last = r.messages.last.time;
    final textCount = r.messages.where((m) => m.attachment == null && _senders.contains(m.sender)).length;
    final mediaCount = prepared.mediaAvailable;
    final samples = prepared.samples();

    return ListView(key: const ValueKey('preview'), padding: const EdgeInsets.all(Space.s600), children: [
      Text('Found ${formatCount(r.messages.length)} messages', style: t.titleLg),
      const SizedBox(height: Space.s100),
      Text('${formatDate(first)} – ${formatDate(last)}', style: t.bodyMd.copyWith(color: c.textSecondary)),
      const SizedBox(height: Space.s600),

      // Date order check (brief §7.12): the format varies by phone region.
      Text(r.dateOrderCertain ? 'Dates look right?' : 'Which way are the dates written?',
          style: t.titleSm),
      const SizedBox(height: Space.s100),
      Text(
        r.dayFirst ? 'We read dates as day/month.' : 'We read dates as month/day.',
        style: t.bodySm.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: Space.s300),
      TibbSegmented<bool>(
        segments: const [(true, 'Day / Month'), (false, 'Month / Day')],
        selected: r.dayFirst,
        onChanged: _reparsing ? null : _setDayFirst,
      ),
      const SizedBox(height: Space.s300),
      AnimatedOpacity(
        opacity: _reparsing ? 0.4 : 1,
        duration: context.motion(Motion.fast),
        child: Container(
          padding: const EdgeInsets.all(Space.s400),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: c.isDark ? null : Border.all(color: c.borderSubtle),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final m in samples)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s100),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 96,
                    child: Text(formatDate(m.time), style: t.monoSm.copyWith(color: c.textTertiary)),
                  ),
                  Expanded(
                    child: Text(m.text.replaceAll('\n', ' '),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
                  ),
                ]),
              ),
            if (samples.isEmpty) Text('Only attachments in this export.', style: t.bodySm),
          ]),
        ),
      ),
      const SizedBox(height: Space.s600),

      if (r.senders.length > 1) ...[
        Text('Whose messages?', style: t.titleSm),
        const SizedBox(height: Space.s100),
        Text('A self-chat usually has one name. Pick yours.', style: t.bodySm.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.s300),
        Wrap(spacing: Space.s200, runSpacing: Space.s200, children: [
          for (final sender in r.senders)
            _Chip(
              label: sender,
              selected: _senders.contains(sender),
              onTap: () => setState(() => _senders.contains(sender) ? _senders.remove(sender) : _senders.add(sender)),
            ),
        ]),
        const SizedBox(height: Space.s600),
      ],

      ListGroup(children: [
        TibbRow(icon: TibbIcons.chat, title: 'Messages and links', value: formatCount(textCount), trailing: const SizedBox()),
        if (mediaCount > 0)
          TibbRow(
            icon: TibbIcons.image,
            title: 'Photos, videos and files',
            subtitle: pro ? null : 'Part of Pro',
            value: formatCount(mediaCount),
            trailing: Switch(value: _includeMedia, onChanged: (v) => setState(() => _includeMedia = v)),
          ),
      ]),
      const SizedBox(height: Space.s400),
      InfoCard(
        tone: InfoTone.info,
        icon: TibbIcons.box,
        title: pro ? 'Goes into a “WhatsApp import” box' : 'Goes into your box’s archive',
        body: pro
            ? 'Original dates are kept. Importing the same export again skips what’s already here.'
            : 'Original dates are kept, and nothing floods your thread. Find it all in Archive or Search.',
      ),
      if (_error != null) ...[
        const SizedBox(height: Space.s400),
        InfoCard(tone: InfoTone.error, title: _error!),
      ],
      const SizedBox(height: Space.s600),
      TibbButton(
        label: _senders.isEmpty ? 'Pick at least one name' : 'Import ${formatCount(textCount + (_includeMedia ? mediaCount : 0))} items',
        onPressed: _senders.isEmpty || _reparsing ? null : _import,
      ),
      const SizedBox(height: Space.s200),
      TibbButton(
        label: 'Choose a different file',
        variant: TibbButtonVariant.ghost,
        size: TibbButtonSize.md,
        onPressed: _pick,
      ),
    ]);
  }

  // ------------------------------------------------------------ importing

  Widget _importing(BuildContext context) {
    final c = context.colors;
    final value = _total == 0 ? null : _done / _total;
    return Center(
      key: const ValueKey('importing'),
      child: Padding(
        padding: const EdgeInsets.all(Space.s600),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const TibbIllustration(Illustration.chatToBox, width: 140),
          const SizedBox(height: Space.s600),
          Text('Tucking ${formatCount(_total)} items away…', style: context.type.titleMd, textAlign: TextAlign.center),
          const SizedBox(height: Space.s200),
          Text('You can leave this screen open. It stays on this phone.',
              textAlign: TextAlign.center, style: context.type.bodySm.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.s600),
          TibbProgress(value: value, label: '${formatCount(_done)} of ${formatCount(_total)}'),
          const SizedBox(height: Space.s600),
          TibbButton(
            label: _cancelled ? 'Stopping…' : 'Stop import',
            variant: TibbButtonVariant.tertiary,
            size: TibbButtonSize.md,
            expand: false,
            onPressed: _cancelled ? null : () => setState(() => _cancelled = true),
          ),
        ]),
      ),
    );
  }

  // ----------------------------------------------------------------- done

  Widget _doneView(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final s = _summary!;
    final repo = AppScope.of(context).repo;
    final extras = [
      if (s.duplicates > 0) '${formatCount(s.duplicates)} already in Tibb were skipped.',
      if (s.missingMedia > 0) '${formatCount(s.missingMedia)} attachments weren’t in the export.',
    ];
    return ListView(key: const ValueKey('done'), padding: const EdgeInsets.all(Space.s600), children: [
      const SizedBox(height: Space.s800),
      const Center(child: LidClose(kind: Illustration.tucked, width: 150)),
      const SizedBox(height: Space.s600),
      Semantics(
        liveRegion: true,
        child: Text(formatCount(s.created), style: t.displayLg, textAlign: TextAlign.center),
      ),
      Text(s.created == 1 ? 'item imported' : 'items imported',
          style: t.titleSm.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: Space.s400),
      Text(
        s.archived
            ? 'They’re archived so your box stays tidy — still searchable, never in the way.'
            : 'They’re in “${s.boxName}”, with their original dates.',
        style: t.bodyMd.copyWith(color: c.textSecondary),
        textAlign: TextAlign.center,
      ),
      for (final e in extras) ...[
        const SizedBox(height: Space.s100),
        Text(e, style: t.bodySm.copyWith(color: c.textTertiary), textAlign: TextAlign.center),
      ],
      const SizedBox(height: Space.s1000),
      TibbButton(
        label: s.archived ? 'Open my box' : 'Open ${s.boxName}',
        onPressed: () => Navigator.of(context).pop(s.boxId),
      ),
      if (s.archived && s.created > 0) ...[
        const SizedBox(height: Space.s200),
        TibbButton(
          label: 'Unarchive all',
          variant: TibbButtonVariant.tertiary,
          onPressed: () {
            repo.unarchiveAll(s.boxId);
            Navigator.of(context).pop(s.boxId);
          },
        ),
      ],
      const SizedBox(height: Space.s400),
      Text('You can delete the export file now.',
          textAlign: TextAlign.center, style: t.bodySm.copyWith(color: c.textTertiary)),
    ]);
  }
}

class _NumberedCard extends StatelessWidget {
  const _NumberedCard({required this.number, required this.title, required this.body});
  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.s400),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? null : Border.all(color: c.borderSubtle),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.highlight, shape: BoxShape.circle),
          child: Text('$number', style: context.type.labelMd.copyWith(color: c.textPrimary)),
        ),
        const SizedBox(width: Space.s300),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.type.titleXs),
            const SizedBox(height: Space.s050),
            Text(body, style: context.type.bodySm.copyWith(color: c.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: context.motion(Motion.fast),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: Space.s400, vertical: Space.s200),
          decoration: BoxDecoration(
            color: selected ? c.highlight : c.surface,
            borderRadius: BorderRadius.circular(Radii.full),
            border: Border.all(color: selected ? c.borderSelected : c.borderDefault, width: selected ? 2 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (selected) ...[Icon(TibbIcons.check, size: 16, color: c.textPrimary), const SizedBox(width: Space.s100)],
            Text(label, style: context.type.labelLg),
          ]),
        ),
      ),
    );
  }
}
