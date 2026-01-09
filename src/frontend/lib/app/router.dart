import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runam/screens/profile/profile_screen.dart';
import '../screens/add_errand/add_errand.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/splash/splash_screen.dart';

final rootNavigatorKey= GlobalKey<NavigatorState>();


final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: HomeScreen.path,
  routes: [
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: SplashScreen.path,
      name: SplashScreen.routeName,
      builder: (_, __) => const SplashScreen(),
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
      path: AddErrandScreen.path,
      name: AddErrandScreen.routeName,
      builder: (_, __) => const AddErrandScreen(),
    ),
  ],
);

