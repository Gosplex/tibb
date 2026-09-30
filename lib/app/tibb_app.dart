import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../features/thread/thread_screen.dart';
import 'app_scope.dart';

class TibbApp extends StatelessWidget {
  const TibbApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Tibb',
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        theme: buildTheme(TibbColors.light),
        darkTheme: buildTheme(TibbColors.dark),
        home: const ThreadScreen(),
      ),
    );
  }
}
