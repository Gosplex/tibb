// Generates the native Android (and iOS) projects around lib/ and applies the
// settings Tibb needs. Works on Windows, macOS and Linux:
//
//   dart run tool/setup.dart          # Android only (default)
//   dart run tool/setup.dart --ios    # also configure iOS (Mac + Xcode)
//
// Safe to re-run: `flutter create` never overwrites existing files and every
// edit below checks before it changes anything.
import 'dart:io';

void main(List<String> args) async {
  final withIos = args.contains('--ios');
  _step('Generating platform folders (flutter create)');
  await _run('flutter', ['create', '--org', 'app.tibb', '--project-name', 'tibb', '--platforms', 'android,ios', '.']);
  final templateTest = File('test/widget_test.dart');
  if (templateTest.existsSync()) templateTest.deleteSync(); // the counter-app test; not ours

  _step('Fetching packages');
  await _run('flutter', ['pub', 'get']);

  _android();
  if (withIos) _ios();
  if (withIos && Platform.isMacOS && Directory('ios').existsSync()) {
    _step('CocoaPods (iOS)');
    await _run('pod', ['install'], workingDirectory: 'ios', required: false);
  }

  final env = File('env.json');
  if (!env.existsSync()) File('env.example.json').copySync('env.json');

  stdout.writeln('''

Done. Next:
  1. Put your RevenueCat Test Store key (starts with test_) in env.json
  2. Plug in your Android phone with USB debugging on
  3. flutter run --dart-define-from-file=env.json
''');
}

void _android() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stdout.writeln('  (no android/ folder — skipped)');
    return;
  }
  _step('Android: permissions, app name, launcher icon');
  var m = manifest.readAsStringSync();
  // INTERNET: sockets for Bridge + RevenueCat. RECORD_AUDIO: voice memos.
  // USE_BIOMETRIC: locked boxes. Nothing else — no location, no contacts.
  for (final perm in ['INTERNET', 'RECORD_AUDIO', 'USE_BIOMETRIC']) {
    if (!m.contains('android.permission.$perm"')) {
      m = m.replaceFirst('<application', '<uses-permission android:name="android.permission.$perm"/>\n    <application');
    }
  }
  m = m.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="Tibb"');
  // No Google auto-backup: Tibb's promise is that nothing leaves the phone
  // unless the user exports it.
  if (!m.contains('android:allowBackup')) {
    m = m.replaceFirst('<application', '<application android:allowBackup="false" android:fullBackupContent="false"');
  }
  manifest.writeAsStringSync(m);

  // local_auth needs a FragmentActivity.
  final activities = Directory('android/app/src/main')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('MainActivity.kt') || f.path.endsWith('MainActivity.java'));
  for (final f in activities) {
    final s = f.readAsStringSync();
    final patched = s
        .replaceAll(RegExp(r'io\.flutter\.embedding\.android\.FlutterActivity\b'),
        'io.flutter.embedding.android.FlutterFragmentActivity')
        .replaceAll(RegExp(r'\bFlutterActivity\(\)'), 'FlutterFragmentActivity()')
        .replaceAll(RegExp(r'extends FlutterActivity\b'), 'extends FlutterFragmentActivity');
    if (patched != s) f.writeAsStringSync(patched);
  }

  // minSdk 24 (Android 7): needed by local_auth / record / RevenueCat.
  for (final path in ['android/app/build.gradle.kts', 'android/app/build.gradle']) {
    final g = File(path);
    if (!g.existsSync()) continue;
    g.writeAsStringSync(g
        .readAsStringSync()
        .replaceAll('minSdk = flutter.minSdkVersion', 'minSdk = 24')
        .replaceAll('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 24'));
  }

  _copyTree(Directory('tool/icon/android/res'), Directory('android/app/src/main/res'));
}

void _ios() {
  final plist = File('ios/Runner/Info.plist');
  if (!plist.existsSync()) return;
  _step('iOS: permission strings, iOS 13 minimum, app icon');
  var s = plist.readAsStringSync();
  const keys = {
    'NSFaceIDUsageDescription': 'Tibb uses Face ID to open the boxes you lock.',
    'NSMicrophoneUsageDescription': 'Tibb records voice memos only while you hold the mic button.',
    'NSPhotoLibraryUsageDescription': 'Tibb saves the photos and videos you pick into your box. They stay on this phone.',
    'NSCameraUsageDescription': 'Tibb saves the photos you take into your box. They stay on this phone.',
    'NSLocalNetworkUsageDescription':
    'Tibb Bridge shows your boxes to your computer over your own Wi-Fi. Nothing goes through the internet.',
  };
  final add = StringBuffer();
  keys.forEach((k, v) {
    if (!s.contains('<key>$k</key>')) add.write('\t<key>$k</key>\n\t<string>$v</string>\n');
  });
  if (add.isNotEmpty) {
    final i = s.lastIndexOf('</dict>');
    s = s.substring(0, i) + add.toString() + s.substring(i);
  }
  s = s.replaceFirstMapped(RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
          (m) => '${m[1]}Tibb${m[2]}');
  plist.writeAsStringSync(s);

  // Raise the deployment target to at least 13.0 (RevenueCat), but never
  // lower it: newer Flutter versions require a higher minimum themselves.
  String raise(Match m, String Function(String) build) {
    final v = double.tryParse(m[1]!) ?? 0;
    return v >= 13.0 ? m[0]! : build('13.0');
  }

  final podfile = File('ios/Podfile');
  if (podfile.existsSync()) {
    podfile.writeAsStringSync(podfile.readAsStringSync().replaceFirstMapped(
        RegExp(r"^# ?platform :ios, '([0-9.]+)'", multiLine: true),
            (m) => "platform :ios, '${(double.tryParse(m[1]!) ?? 0) >= 13.0 ? m[1] : '13.0'}'"));
  }
  final pbx = File('ios/Runner.xcodeproj/project.pbxproj');
  if (pbx.existsSync()) {
    pbx.writeAsStringSync(pbx.readAsStringSync().replaceAllMapped(
        RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);'),
            (m) => raise(m, (v) => 'IPHONEOS_DEPLOYMENT_TARGET = $v;')));
  }
  final iconDir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
  if (iconDir.existsSync()) {
    for (final f in iconDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png'))) {
      f.deleteSync();
    }
    File('tool/icon/AppIcon-1024.png').copySync('${iconDir.path}/AppIcon-1024.png');
    File('${iconDir.path}/Contents.json').writeAsStringSync('''
{
  "images" : [
    { "filename" : "AppIcon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
''');
  }
}

void _copyTree(Directory from, Directory to) {
  for (final e in from.listSync(recursive: true).whereType<File>()) {
    final rel = e.path.substring(from.path.length + 1);
    final target = File('${to.path}${Platform.pathSeparator}$rel');
    target.parent.createSync(recursive: true);
    e.copySync(target.path);
  }
}

void _step(String s) => stdout.writeln('→ $s');

Future<void> _run(String cmd, List<String> args, {String? workingDirectory, bool required = true}) async {
  final p = await Process.start(cmd, args,
      workingDirectory: workingDirectory, runInShell: true, mode: ProcessStartMode.inheritStdio);
  final code = await p.exitCode;
  if (code != 0 && required) {
    stderr.writeln('"$cmd ${args.join(' ')}" failed (exit $code).');
    exit(code);
  }
}