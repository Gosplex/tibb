// Formatting helpers. One place for how Tibb writes dates, sizes and durations.

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Day separator label: "Today", "Yesterday", "Mon 14 Sep", "14 Sep 2025".
String formatDay(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (t.year == n.year) {
    return diff < 7
        ? '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}'
        : '${t.day} ${_months[t.month - 1]}';
  }
  return '${t.day} ${_months[t.month - 1]} ${t.year}';
}

String formatDate(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';

String formatBytes(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String formatCount(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Human-readable browser name from a User-Agent, e.g. "Chrome on Windows".
String deviceNameFromUserAgent(String? ua) {
  if (ua == null || ua.isEmpty) return 'A computer';
  var browser = 'Browser';
  if (ua.contains('Edg/')) {
    browser = 'Edge';
  } else if (ua.contains('OPR/') || ua.contains('Opera')) {
    browser = 'Opera';
  } else if (ua.contains('Firefox/')) {
    browser = 'Firefox';
  } else if (ua.contains('Chrome/')) {
    browser = 'Chrome';
  } else if (ua.contains('Safari/')) {
    browser = 'Safari';
  }
  var os = 'a computer';
  if (ua.contains('Windows')) {
    os = 'Windows';
  } else if (ua.contains('Mac OS X') || ua.contains('Macintosh')) {
    os = 'Mac';
  } else if (ua.contains('CrOS')) {
    os = 'Chromebook';
  } else if (ua.contains('Linux')) {
    os = 'Linux';
  }
  return '$browser on $os';
}

/// MIME type from a file name, for items saved without a reported type.
String mimeFromName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  const map = {
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif',
    'webp': 'image/webp', 'heic': 'image/heic', 'heif': 'image/heif',
    'mp4': 'video/mp4', 'mov': 'video/quicktime', 'm4v': 'video/x-m4v', 'webm': 'video/webm',
    'm4a': 'audio/mp4', 'aac': 'audio/aac', 'mp3': 'audio/mpeg', 'wav': 'audio/wav',
    'opus': 'audio/ogg', 'ogg': 'audio/ogg',
    'pdf': 'application/pdf', 'zip': 'application/zip', 'txt': 'text/plain',
    'json': 'application/json', 'csv': 'text/csv',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };
  return map[ext] ?? 'application/octet-stream';
}

final RegExp _urlPattern = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

/// True when the whole text is a single URL (renders as a link item).
bool isSingleUrl(String text) {
  final t = text.trim();
  final m = _urlPattern.firstMatch(t);
  return m != null && m.start == 0 && m.end == t.length;
}

Iterable<RegExpMatch> findUrls(String text) => _urlPattern.allMatches(text);
