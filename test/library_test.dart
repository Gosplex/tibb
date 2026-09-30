import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tibb/core/blobs/blob_store.dart';
import 'package:tibb/core/db/database.dart';
import 'package:tibb/core/models.dart';
import 'package:tibb/core/repository/library_repository.dart';
import 'package:tibb/features/export_import/archive_service.dart';

// Needs a host SQLite with FTS5 (macOS system SQLite has it).
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('tibb-lib'));
  tearDown(() async => dir.delete(recursive: true));

  Future<LibraryRepository> newRepo(String name) async {
    final blobs = BlobStore(Directory('${dir.path}/$name-blobs'));
    await blobs.init();
    return LibraryRepository.openWith(openInMemoryTibbDatabase(), blobs);
  }

  test('first run seeds one box with one item', () async {
    final repo = await newRepo('a');
    expect(repo.boxes(), hasLength(1));
    expect(repo.items(repo.defaultBoxId), hasLength(1));
  });

  test('links are detected, search finds text, deletes are tombstones with undo', () async {
    final repo = await newRepo('a');
    final box = repo.defaultBoxId;
    final link = repo.addText(box, 'https://example.com/x');
    expect(link.type, ItemType.link);
    final note = repo.addText(box, 'passport renewal form');
    expect(repo.search('passp').map((r) => r.item.id), contains(note.id));
    repo.deleteItem(note.id);
    expect(repo.search('passport'), isEmpty);
    repo.restoreItem(note.id);
    expect(repo.search('passport'), hasLength(1));
  });

  test('applying the same events twice is a no-op', () async {
    final repo = await newRepo('a');
    final events = repo.log.allEvents();
    expect(repo.applyForeignEvents(events), 0);
  });

  test('export then import into a fresh library copies everything, and re-import adds nothing', () async {
    final a = await newRepo('a');
    final boxId = a.defaultBoxId;
    a.addText(boxId, 'hello from A');
    final src = File('${dir.path}/photo.jpg')..writeAsBytesSync(List<int>.generate(5000, (i) => i % 256));
    final blob = await a.blobs.ingestFile(src, mime: 'image/jpeg');
    a.addBlob(boxId, blob, fileName: 'photo.jpg');

    final archive = await ArchiveService(a, workDir: dir).export(password: 'long password');
    final b = await newRepo('b');
    final before = b.itemCount();
    final r = await ArchiveService(b, workDir: dir).import(archive, password: 'long password');
    expect(b.itemCount() - before, a.itemCount());
    expect(r.blobs, 1);
    expect(await b.blobs.exists(blob.hash, 'image/jpeg'), isTrue);

    final again = await ArchiveService(b, workDir: dir).import(archive, password: 'long password');
    expect(again.newEvents, 0);
  });
}
