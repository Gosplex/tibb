import 'package:flutter_test/flutter_test.dart';
import 'package:tibb/features/whatsapp_import/whatsapp_parser.dart';

void main() {
  group('parseWhatsApp', () {
    test('iPhone 24h format with attachments and multi-line text', () {
      const raw = '[25/09/2026, 14:22:10] Priya: Buy milk\n'
          'and eggs\n'
          '\u200e[25/09/2026, 14:23:01] Priya: \u200e<attached: 00000012-PHOTO-2026-09-25-14-23-01.jpg>\n'
          '[26/09/2026, 09:00:00] Priya: https://example.com/a';
      final r = parseWhatsApp(raw);
      expect(r.messages, hasLength(3));
      expect(r.messages[0].text, 'Buy milk\nand eggs');
      expect(r.messages[0].time, DateTime(2026, 9, 25, 14, 22, 10));
      expect(r.messages[1].attachment, '00000012-PHOTO-2026-09-25-14-23-01.jpg');
      expect(r.attachmentCount, 1);
      expect(r.senders, ['Priya']);
    });

    test('Android 12h month-first format with narrow no-break space', () {
      const raw = '9/25/26, 2:22\u202fPM - Sam: hello\n'
          '9/25/26, 12:05\u202fAM - Sam: IMG-20260925-WA0001.jpg (file attached)\n'
          '9/25/26, 12:06\u202fPM - Messages and calls are end-to-end encrypted.';
      final r = parseWhatsApp(raw);
      expect(r.messages, hasLength(2));
      expect(r.messages[0].time, DateTime(2026, 9, 25, 14, 22));
      expect(r.messages[1].time, DateTime(2026, 9, 25, 0, 5));
      expect(r.messages[1].attachment, 'IMG-20260925-WA0001.jpg');
      expect(r.skippedSystemLines, 1);
    });

    test('ambiguous dates default to day-first', () {
      final r = parseWhatsApp('03/04/2026, 10:00 - Me: note');
      expect(r.messages.single.time, DateTime(2026, 4, 3, 10, 0));
    });

    test('media omitted lines are skipped', () {
      final r = parseWhatsApp('13/04/2026, 10:00 - Me: <Media omitted>\n13/04/2026, 10:01 - Me: ok');
      expect(r.messages.single.text, 'ok');
    });

    test('ambiguous files are flagged so the user confirms the order', () {
      final r = parseWhatsApp('03/04/2026, 10:00 - Me: note');
      expect(r.dateOrderCertain, isFalse);
      expect(r.dayFirst, isTrue);
    });

    test('the user can override the date order', () {
      final r = parseWhatsApp('03/04/2026, 10:00 - Me: note', dayFirst: false);
      expect(r.messages.single.time, DateTime(2026, 3, 4, 10, 0));
      expect(r.dayFirst, isFalse);
    });

    test('evidence in the file decides the order', () {
      final (dayFirst, certain) = detectDateOrder('03/04/2026, 10:00 - Me: a\n25/04/2026, 10:00 - Me: b');
      expect(dayFirst, isTrue);
      expect(certain, isTrue);
    });
  });
}
