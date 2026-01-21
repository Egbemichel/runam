import 'dart:async';

import 'package:flutter/material.dart';
import 'theme.dart';
import 'router.dart';
import 'package:runam/screens/runner/runner_request_accept.dart';
import '../controllers/runner_offer_controller.dart';
import 'package:get/get.dart';

/// Global scaffold messenger key for showing snackbars from anywhere
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>(debugLabel: 'scaffoldMessenger');

class RunAmApp extends StatefulWidget {
  const RunAmApp({super.key});

  @override
  State<RunAmApp> createState() => _RunAmAppState();
}

class _RunAmAppState extends State<RunAmApp> {
  StreamSubscription? _offersSub;

  @override
  void initState() {
    super.initState();
    // Delay subscription until after first frame so navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final controller = Get.find<RunnerOfferController>();
        _offersSub = controller.offers.listen((offers) {
          // Keep minimal logging here. GoRouter redirect (refreshListenable) handles navigation.
          debugPrint('[RunAmApp] Session-level offers count: ${offers.length}');
        });
      } catch (e) {
        debugPrint('[RunAmApp] RunnerOfferController not available: $e');
      }
    });
  }

  @override
  void dispose() {
    _offersSub?.cancel();
    super.dispose();
  }

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
