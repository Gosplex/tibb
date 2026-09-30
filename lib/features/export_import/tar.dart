// Minimal streaming POSIX ustar writer/reader. Tibb archives are plain tar so
// they open with any standard tool (tar on Windows 10+, macOS, Linux) and
// large media streams to/from disk without ever being held in memory.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class TarWriter {
  TarWriter(this._sink);
  final IOSink _sink;

  Future<void> addBytes(String name, List<int> bytes) async {
    _sink.add(_header(name, bytes.length));
    _sink.add(bytes);
    _pad(bytes.length);
  }

  Future<void> addFile(String name, File file) async {
    final length = await file.length();
    _sink.add(_header(name, length));
    await _sink.addStream(file.openRead());
    _pad(length);
  }

  /// Writes the two zero blocks that end a tar archive.
  Future<void> close() async {
    _sink.add(Uint8List(1024));
    await _sink.flush();
    await _sink.close();
  }

  void _pad(int length) {
    final rem = length % 512;
    if (rem != 0) _sink.add(Uint8List(512 - rem));
  }

  static Uint8List _header(String name, int size) {
    final nameBytes = utf8.encode(name);
    if (nameBytes.length > 100) throw ArgumentError('tar entry name too long: $name');
    final h = Uint8List(512);
    h.setRange(0, nameBytes.length, nameBytes);
    void octal(int offset, int width, int value) {
      final s = value.toRadixString(8).padLeft(width - 1, '0');
      h.setRange(offset, offset + width - 1, ascii.encode(s));
      h[offset + width - 1] = 0;
    }

    octal(100, 8, 420); // mode 0644
    octal(108, 8, 0); // uid
    octal(116, 8, 0); // gid
    octal(124, 12, size);
    octal(136, 12, DateTime.now().millisecondsSinceEpoch ~/ 1000);
    h[156] = 0x30; // typeflag '0' = regular file
    h.setRange(257, 263, ascii.encode('ustar\u0000'));
    h.setRange(263, 265, ascii.encode('00'));
    // Checksum is computed with the checksum field set to spaces.
    for (var i = 148; i < 156; i++) {
      h[i] = 0x20;
    }
    final sum = h.fold<int>(0, (a, b) => a + b);
    final cs = sum.toRadixString(8).padLeft(6, '0');
    h.setRange(148, 154, ascii.encode(cs));
    h[154] = 0;
    h[155] = 0x20;
    return h;
  }
}

class TarEntry {
  TarEntry(this.name, this.size);
  final String name;
  final int size;
}

class TarFormatException implements Exception {
  const TarFormatException(this.message);
  final String message;
  @override
  String toString() => 'TarFormatException: $message';
}

/// Reads a tar file entry by entry. [onEntry] must consume the provided
/// stream fully (or return without listening — the reader then skips it).
Future<void> readTar(File file, Future<void> Function(TarEntry entry, Stream<List<int>> data) onEntry) async {
  final raf = await file.open();
  try {
    final total = await raf.length();
    var pos = 0;
    while (pos + 512 <= total) {
      await raf.setPosition(pos);
      final header = await raf.read(512);
      if (header.every((b) => b == 0)) break; // end-of-archive marker
      if (!_checksumOk(header)) throw const TarFormatException('bad header checksum');
      final name = _string(header, 0, 100);
      final prefix = _string(header, 345, 155);
      final fullName = prefix.isEmpty ? name : '$prefix/$name';
      final size = int.parse(_string(header, 124, 12).trim().isEmpty ? '0' : _string(header, 124, 12).trim(), radix: 8);
      final type = header[156];
      final dataStart = pos + 512;
      if (dataStart + size > total) throw const TarFormatException('truncated archive');
      if (type == 0x30 || type == 0) {
        await onEntry(TarEntry(fullName, size), file.openRead(dataStart, dataStart + size));
      }
      pos = dataStart + ((size + 511) ~/ 512) * 512;
    }
  } finally {
    await raf.close();
  }
}

String _string(List<int> bytes, int start, int length) {
  var end = start;
  while (end < start + length && bytes[end] != 0) {
    end++;
  }
  return utf8.decode(bytes.sublist(start, end), allowMalformed: true);
}

bool _checksumOk(List<int> header) {
  final stored = int.tryParse(_string(header, 148, 8).trim(), radix: 8);
  if (stored == null) return false;
  var sum = 0;
  for (var i = 0; i < 512; i++) {
    sum += (i >= 148 && i < 156) ? 0x20 : header[i];
  }
  return sum == stored;
}
