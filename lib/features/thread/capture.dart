// Capture flows: photos/videos, camera, files, clipboard paste. Each one
// streams into the BlobStore (hash + dedupe) and then creates one item through
// the repository — the same path Bridge uploads use.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../app/app_scope.dart';
import '../../core/blobs/blob_store.dart';
import '../../core/models.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../paywall/paywall_sheet.dart';

enum AttachChoice { media, camera, files, paste }

Future<void> showAttachSheet(BuildContext context, String boxId) async {
  final pro = AppScope.of(context).pro;
  final choice = await showTibbSheet<AttachChoice>(context, builder: (ctx) {
    final c = ctx.colors;
    Widget row(AttachChoice v, IconData icon, String label, {bool proOnly = false}) => InkWell(
          onTap: () => Navigator.of(ctx).pop(v),
          borderRadius: BorderRadius.circular(Radii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s300, horizontal: Space.s100),
            child: Row(children: [
              Icon(icon, color: c.textPrimary),
              const SizedBox(width: Space.s300),
              Expanded(child: Text(label, style: ctx.type.bodyLg)),
              if (proOnly && !pro.isPro) TibbTag(label: 'Pro', fg: c.textAccent, bg: c.highlight),
            ]),
          ),
        );
    return SheetScaffold(
      title: 'Add to box',
      child: Column(children: [
        row(AttachChoice.media, TibbIcons.image, 'Photos & videos', proOnly: true),
        row(AttachChoice.camera, TibbIcons.camera, 'Take a photo', proOnly: true),
        row(AttachChoice.files, TibbIcons.file, 'Files', proOnly: true),
        row(AttachChoice.paste, TibbIcons.clipboard, 'Paste from clipboard'),
      ]),
    );
  });
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case AttachChoice.media:
      await pickMedia(context, boxId);
    case AttachChoice.camera:
      await takePhoto(context, boxId);
    case AttachChoice.files:
      await pickFiles(context, boxId);
    case AttachChoice.paste:
      await pasteClipboard(context, boxId);
  }
}

Future<void> pickMedia(BuildContext context, String boxId) async {
  if (!await ensurePro(context, PaywallReason.media)) return;
  // imageQuality makes iOS hand back JPEG instead of HEIC, so photos also
  // render in the Bridge page on Windows/Chrome. Video is untouched.
  final files = await ImagePicker().pickMultipleMedia(imageQuality: 92);
  if (files.isEmpty || !context.mounted) return;
  await _ingestAll(context, boxId, [
    for (final f in files) (File(f.path), f.name, f.mimeType ?? mimeFromName(f.name)),
  ]);
}

Future<void> takePhoto(BuildContext context, String boxId) async {
  if (!await ensurePro(context, PaywallReason.media)) return;
  final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 92);
  if (f == null || !context.mounted) return;
  await _ingestAll(context, boxId, [(File(f.path), f.name, f.mimeType ?? 'image/jpeg')], deleteSource: true);
}

Future<void> pickFiles(BuildContext context, String boxId) async {
  if (!await ensurePro(context, PaywallReason.media)) return;
  final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
  if (result == null || !context.mounted) return;
  await _ingestAll(context, boxId, [
    for (final f in result.files)
      if (f.path != null) (File(f.path!), f.name, mimeFromName(f.name)),
  ]);
}

Future<void> pasteClipboard(BuildContext context, String boxId) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text?.trim() ?? '';
  if (!context.mounted) return;
  if (text.isEmpty) {
    showToast(context, 'Your clipboard is empty.');
    return;
  }
  AppScope.of(context).repo.addText(boxId, text);
  HapticFeedback.lightImpact();
}

Future<void> saveVoiceMemo(BuildContext context, String boxId, File file, Duration duration) async {
  final repo = AppScope.of(context).repo;
  try {
    final blob = await repo.blobs.ingestFile(file, mime: 'audio/mp4', deleteSource: true);
    repo.addBlob(boxId, blob,
        fileName: 'Voice memo ${formatTime(DateTime.now())}.m4a',
        type: ItemType.voice,
        durationMs: duration.inMilliseconds);
    HapticFeedback.lightImpact();
  } on StorageFullException {
    if (context.mounted) showToast(context, "Your phone is full. Free up space and try again.");
  }
}

Future<void> _ingestAll(BuildContext context, String boxId, List<(File, String, String)> files,
    {bool deleteSource = false}) async {
  final repo = AppScope.of(context).repo;
  var saved = 0;
  for (final (file, name, mime) in files) {
    try {
      final blob = await repo.blobs.ingestFile(file, mime: mime, deleteSource: deleteSource);
      repo.addBlob(boxId, blob, fileName: name.isEmpty ? p.basename(file.path) : name);
      saved++;
    } on StorageFullException {
      if (context.mounted) showToast(context, 'Your phone is full. $saved saved — free up space for the rest.');
      return;
    } catch (_) {
      if (context.mounted) showToast(context, "Couldn't save $name. Try again.");
    }
  }
  if (saved > 0) HapticFeedback.lightImpact();
}
