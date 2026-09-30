// Export / import screens (design S17/S18). Export is always free (brief §9.5).
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_scope.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/tibb_button.dart';
import 'archive_service.dart';
import 'crypto_box.dart';

Future<void> showExportSheet(BuildContext context) =>
    showTibbSheet<void>(context, builder: (_) => const _ExportSheet());

class _ExportSheet extends StatefulWidget {
  const _ExportSheet();

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _protect = true;
  bool _obscure = true;
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  String? _error;
  String? _stage;
  double _progress = 0;

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    if (_protect) {
      if (_pw.text.length < 8) {
        setState(() => _error = 'Use at least 8 characters.');
        return;
      }
      if (_pw.text != _pw2.text) {
        setState(() => _error = "The passwords don't match.");
        return;
      }
    }
    setState(() {
      _error = null;
      _stage = 'Preparing';
      _progress = 0;
    });
    final repo = AppScope.of(context).repo;
    try {
      final file = await ArchiveService(repo).export(
        password: _protect ? _pw.text : null,
        onProgress: (stage, v) {
          if (mounted) setState(() {
            _stage = stage;
            _progress = v;
          });
        },
      );
      if (!mounted) return;
      final size = formatBytes(await file.length());
      if (!mounted) return;
      setState(() => _stage = null);
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: 'Tibb export ($size)',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
      repo.setMeta('last_export', DateTime.now().toIso8601String());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = null;
          _error = "Export didn't finish. Check you have free space and try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final repo = AppScope.of(context).repo;
    final busy = _stage != null;
    return SheetScaffold(
      title: 'Export everything',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('One file with every box, item, note and photo. Keep it somewhere safe — '
            'you can import it on any phone with Tibb.',
            style: t.bodyMd.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.s200),
        Text('${formatCount(repo.itemCount())} items', style: t.caption.copyWith(color: c.textTertiary)),
        const SizedBox(height: Space.s600),
        Row(children: [
          Icon(TibbIcons.key, color: c.privateFg),
          const SizedBox(width: Space.s300),
          Expanded(child: Text('Protect with a password', style: t.bodyMd)),
          Switch(value: _protect, onChanged: busy ? null : (v) => setState(() => _protect = v)),
        ]),
        if (_protect) ...[
          const SizedBox(height: Space.s300),
          TextField(
            controller: _pw,
            obscureText: _obscure,
            enabled: !busy,
            autocorrect: false,
            enableSuggestions: false,
            style: t.input,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? TibbIcons.eye : TibbIcons.eyeOff),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: Space.s300),
          TextField(
            controller: _pw2,
            obscureText: _obscure,
            enabled: !busy,
            autocorrect: false,
            enableSuggestions: false,
            style: t.input,
            decoration: const InputDecoration(labelText: 'Type it again'),
          ),
          const SizedBox(height: Space.s300),
          const InfoCard(
            tone: InfoTone.warning,
            title: 'There is no password reset',
            body: 'Tibb has no account and no server. If you forget this password, the export can’t be opened.',
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: Space.s300),
          Text(_error!, style: t.error.copyWith(color: c.errorFg)),
        ],
        const SizedBox(height: Space.s600),
        if (busy) ...[
          Text('$_stage…', style: t.bodySm.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.s200),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 4),
          ),
          const SizedBox(height: Space.s400),
        ],
        TibbButton(label: 'Export', icon: TibbIcons.exportIcon, loading: busy, onPressed: _export),
      ]),
    );
  }
}

/// Picks a .tibb file and imports it, asking for a password when needed.
Future<void> startImport(BuildContext context) async {
  final repo = AppScope.of(context).repo;
  final picked = await FilePicker.platform.pickFiles(type: FileType.any, withData: false);
  final path = picked?.files.single.path;
  if (path == null || !context.mounted) return;
  final file = File(path);
  final service = ArchiveService(repo);

  String? password;
  if (await service.needsPassword(file)) {
    if (!context.mounted) return;
    password = await _askPassword(context);
    if (password == null) return;
  }
  if (!context.mounted) return;

  final progress = ValueNotifier<String>('Reading');
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(children: [
        const CircularProgressIndicator(),
        const SizedBox(width: Space.s400),
        Expanded(child: ValueListenableBuilder<String>(valueListenable: progress, builder: (_, v, __) => Text('$v…'))),
      ]),
    ),
  );
  String message;
  try {
    final r = await service.import(file, password: password, onProgress: (stage, _) => progress.value = stage);
    message = r.newItems == 0 && r.newEvents == 0
        ? 'Everything in that export is already here.'
        : 'Imported ${formatCount(r.newItems)} item${r.newItems == 1 ? '' : 's'}.';
  } on WrongPasswordException {
    message = "That password didn't open this export. Nothing was imported.";
  } on InvalidArchiveException catch (e) {
    message = e.message;
  } on CorruptArchiveException {
    message = 'This export is damaged. Nothing was imported.';
  } catch (_) {
    message = "Import didn't finish. Nothing was changed.";
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  progress.dispose();
  showToast(context, message);
}

Future<String?> _askPassword(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('This export is protected'),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Password'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Open')),
      ],
    ),
  );
}
