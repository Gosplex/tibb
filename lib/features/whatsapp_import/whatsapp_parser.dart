// Parses WhatsApp "Export chat" text files (brief §7.12). Pure Dart, no I/O,
// so it's unit-tested directly (test/whatsapp_parser_test.dart).
//
// iPhone:  [25/09/2026, 14:22:10] Sam: text      <attached: 00000012-PHOTO-….jpg>
// Android: 25/09/2026, 14:22 - Sam: text          IMG-20260925-WA0001.jpg (file attached)
// Both come in 12 h variants ("2:22 PM", often with a narrow no-break space)
// and in day-first or month-first order depending on phone region.

class WaMessage {
  WaMessage({required this.time, required this.sender, required this.text, this.attachment});
  final DateTime time;
  final String sender;
  String text;
  final String? attachment; // file name inside the export
}

class WaParseResult {
  const WaParseResult(
    this.messages, {
    required this.senders,
    required this.skippedSystemLines,
    this.dayFirst = true,
    this.dateOrderCertain = true,
  });
  final List<WaMessage> messages;
  final List<String> senders; // by message count, most first
  final int skippedSystemLines;

  /// The date order used to read this file (day/month or month/day).
  final bool dayFirst;

  /// False when every date in the file fits both orders (all days ≤ 12), so
  /// the user should confirm it with a preview (brief §7.12).
  final bool dateOrderCertain;

  int get attachmentCount => messages.where((m) => m.attachment != null).length;
}

final _header = RegExp(
  r'^\[?(\d{1,4})[./-](\d{1,2})[./-](\d{1,4}),?\s+(\d{1,2})[:.](\d{2})(?:[:.](\d{2}))?\s*([AaPp]\.?\s?[Mm]\.?)?\]?\s*(?:-\s+)?(.*)$',
);
final _iosAttachment = RegExp(r'^<attached:\s*(.+?)>\s*$');
final _androidAttachment = RegExp(r'^(.+?\.[A-Za-z0-9]{2,5}) \(file attached\)\s*$');

String _clean(String line) => line
    .replaceAll(RegExp('[\u200e\u200f\ufeff\u202a-\u202e]'), '')
    .replaceAll(RegExp('[\u202f\u00a0]'), ' ');

/// Detects the date order from the evidence in the file:
/// (dayFirst, certain). Undecided files default to day-first.
(bool, bool) detectDateOrder(String raw) {
  for (final l in raw.split(RegExp(r'\r?\n'))) {
    final m = _header.firstMatch(_clean(l));
    if (m == null || m.group(1)!.length == 4) continue;
    final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!);
    if (a > 12) return (true, true);
    if (b > 12) return (false, true);
  }
  return (true, false);
}

/// Parses an export. Pass [dayFirst] to override the detected date order
/// (the user's choice in the import preview).
WaParseResult parseWhatsApp(String raw, {bool? dayFirst}) {
  final lines = raw.split(RegExp(r'\r?\n'));
  final (detected, certain) = detectDateOrder(raw);
  return _parse(lines, dayFirst ?? detected, dayFirst != null || certain);
}

WaParseResult _parse(List<String> lines, bool dayFirst, bool certain) {
  final messages = <WaMessage>[];
  final counts = <String, int>{};
  var skipped = 0;
  WaMessage? current;

  for (final rawLine in lines) {
    final line = _clean(rawLine);
    final m = _header.firstMatch(line);
    DateTime? time;
    if (m != null) time = _time(m, dayFirst);

    if (m == null || time == null) {
      // Continuation of a multi-line message.
      if (current != null && current.attachment == null) {
        current.text = current.text.isEmpty ? line : '${current.text}\n$line';
      }
      continue;
    }

    final rest = m.group(8)!;
    final colon = rest.indexOf(': ');
    if (colon <= 0) {
      skipped++; // "Messages are end-to-end encrypted", "You created group", …
      current = null;
      continue;
    }
    final sender = rest.substring(0, colon).trim();
    final body = rest.substring(colon + 2).trim();

    String? attachment;
    var text = body;
    final ios = _iosAttachment.firstMatch(body);
    final android = _androidAttachment.firstMatch(body);
    if (ios != null) {
      attachment = ios.group(1)!.trim();
      text = '';
    } else if (android != null) {
      attachment = android.group(1)!.trim();
      text = '';
    } else if (body == '<Media omitted>' || body == 'image omitted' || body == 'video omitted' ||
        body == 'audio omitted' || body == 'document omitted' || body == 'sticker omitted') {
      // Exported "without media": nothing to bring over.
      skipped++;
      current = null;
      continue;
    }

    current = WaMessage(time: time, sender: sender, text: text, attachment: attachment);
    messages.add(current);
    counts[sender] = (counts[sender] ?? 0) + 1;
  }

  final senders = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return WaParseResult(messages,
      senders: senders, skippedSystemLines: skipped, dayFirst: dayFirst, dateOrderCertain: certain);
}

DateTime? _time(RegExpMatch m, bool dayFirst) {
  final g1 = m.group(1)!, g2 = int.parse(m.group(2)!), g3 = m.group(3)!;
  int year, month, day;
  if (g1.length == 4) {
    year = int.parse(g1);
    month = g2;
    day = int.parse(g3);
  } else {
    final a = int.parse(g1);
    year = int.parse(g3);
    if (g3.length <= 2) year += 2000;
    day = dayFirst ? a : g2;
    month = dayFirst ? g2 : a;
  }
  var hour = int.parse(m.group(4)!);
  final minute = int.parse(m.group(5)!);
  final second = m.group(6) == null ? 0 : int.parse(m.group(6)!);
  final ampm = m.group(7)?.toLowerCase().replaceAll(RegExp(r'[.\s]'), '');
  if (ampm == 'pm' && hour < 12) hour += 12;
  if (ampm == 'am' && hour == 12) hour = 0;
  if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59) return null;
  return DateTime(year, month, day, hour, minute, second);
}
