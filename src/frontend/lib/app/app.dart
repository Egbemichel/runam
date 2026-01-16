import 'package:flutter/material.dart';
import 'theme.dart';
import 'router.dart';

/// Global scaffold messenger key for showing snackbars from anywhere
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>(debugLabel: 'scaffoldMessenger');

class RunAmApp extends StatelessWidget {
  const RunAmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RunAm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: appRouter,
      scaffoldMessengerKey: scaffoldMessengerKey,
    );
  }
}
