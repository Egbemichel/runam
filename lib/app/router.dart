import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/splash/splash_screen.dart';


final appRouter = GoRouter(
  initialLocation: UnauthenticatedHomeScreen.path,
  routes: [
    GoRoute(
      path: SplashScreen.path,
      name: SplashScreen.routeName,
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: OnboardingScreen.path,
      name: OnboardingScreen.routeName,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: UnauthenticatedHomeScreen.path,
      name: UnauthenticatedHomeScreen.routeName,
      builder: (_, __) => const UnauthenticatedHomeScreen(),
    ),
  ],
);

