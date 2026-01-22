import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runam/features/errand/screens/errand_searching.dart';
import 'package:runam/screens/runner/runner_request_accept.dart';
import 'package:runam/screens/profile/profile_screen.dart';
import 'package:get/get.dart';
import '../controllers/runner_offer_controller.dart';
import '../controllers/auth_controller.dart';
import '../features/errand/screens/add_errand.dart';
import '../features/errand/screens/my_errands_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../features/errand/screens/errand_in_progress.dart';

final rootNavigatorKey= GlobalKey<NavigatorState>();


final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: HomeScreen.path,
  refreshListenable: offersRefresh,
  redirect: (context, state) {
    try {
      final controller = Get.find<RunnerOfferController>();
      debugPrint('[router] redirect evaluated; controller.hasOffers=${controller.hasOffers}');
      if (controller.hasOffers) {
        // avoid redirect loop when already on runner dashboard
        if (state.name != RunnerDashboard.routeName) {
          debugPrint('[router] redirecting to RunnerDashboard');
          return RunnerDashboard.path;
        }
      }
    } catch (_) {}
    return null;
  },
  routes: [
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: SplashScreen.path,
      name: SplashScreen.routeName,
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/errand-in-progress',
      name: 'errand-in-progress',
      builder: (context, state) {
        // Pass the errand data via state.extra
        final errand = state.extra as Map<String, dynamic>;
        final authController = Get.find<AuthController>();
        final bool isRunner = authController.isRunnerActive;
        return ErrandInProgressScreen(
          errand: errand,
          isRunner: isRunner,
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: OnboardingScreen.path,
      name: OnboardingScreen.routeName,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: HomeScreen.path,
      name: HomeScreen.routeName,
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: ProfileScreen.path,
      name: ProfileScreen.routeName,
      builder: (_, __) => const ProfileScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: RunnerDashboard.path,
      name: RunnerDashboard.routeName,
      builder: (_, __) => const RunnerDashboard(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AddErrandScreen.path,
      name: AddErrandScreen.routeName,
      builder: (_, __) => const AddErrandScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: MyErrandsScreen.path,
      name: MyErrandsScreen.routeName,
      builder: (_, __) => const MyErrandsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: ErrandSearchingScreen.path + '/:errandId',
      name: ErrandSearchingScreen.routeName,
      builder: (context, state) {
        final errandId = state.pathParameters['errandId']!;
        return ErrandSearchingScreen(errandId: errandId);
      },
    )
  ],
);
