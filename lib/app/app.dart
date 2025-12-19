import 'package:flutter/material.dart';
import 'theme.dart';
import 'router.dart';


class RunAmApp extends StatelessWidget {
  const RunAmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RunAm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: appRouter,
    );
  }
}
