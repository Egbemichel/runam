import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runam/app/theme.dart';

import '../../components/onboarding_content.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String routeName = "onboarding";
  static const String path = "/onboarding";

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Data for our onboarding steps
  final List<Map<String, dynamic>> _pages = [
    {
      "image": "assets/images/Saly-7.png",
      "title": "You forget errands...",
      "smallText": "but never your phone",
      "description": "Good that's all you need to get things done around campus.",
      "button": "Next",
      "showSkip": true,
    },
    {
      "image": "assets/images/Saly-1.png",
      "title": "Chores blocking your day?",
      "smallText": " unblock it",
      "description": "Post it. Pick a runner. Relax while someone else does the sweaty part.",
      "button": "Get Started",
      "showSkip": false,
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary500,
      body: Stack(
        children: [
          // 1. The Swipeable Content
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return OnboardingContent(
                image: _pages[index]['image'],
                title: _pages[index]['title'],
                smallText: _pages[index]['smallText'],
                description: _pages[index]['description'],
                buttonText: _pages[index]['button'],
                showSkip: _pages[index]['showSkip'],
                onSkipPressed: () => _pageController.jumpToPage(_pages.length - 1),
                onButtonPressed: () {
                  if (_currentPage == _pages.length - 1) {
                    // Navigate to Home using go_router
                    context.go('/home');
                  } else {
                    // Move to the next onboarding page
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              );
            },
          ),

          // 2. The Dot Indicators (Positioned at the top)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 10,
                  width: _currentPage == index ? 25 : 10, // Active dot is wider
                  decoration: BoxDecoration(
                    color: _currentPage == index ? AppTheme.secondary500 : Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}