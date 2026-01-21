
import 'package:flutter/material.dart';
import '../app/theme.dart';

class OnboardingContent extends StatelessWidget {
  final String image, title, description, buttonText, smallText;
  final bool showSkip;
  final VoidCallback onButtonPressed;
  final VoidCallback? onSkipPressed;


  const OnboardingContent({
    super.key,
    required this.image,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onButtonPressed,
    required this.smallText,
    this.showSkip = true,
    this.onSkipPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, // IMPORTANT: allows overlap
      children: [
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.38,
          left: 200,
          right: 0,
          child: Container(
            height: 146,
            decoration: BoxDecoration(
              color: AppTheme.secondary500.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(100),
              ),
            ),
          ),
        ),

        // =========================
        // Bottom Content Card
        // =========================
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.45,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            decoration: const BoxDecoration(
              color: AppTheme.secondary500,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                if (showSkip)
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: onSkipPressed,
                      child: Text(
                        'Skip',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.primary700),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                Text(
                  description,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary700,
                  ),
                ),

                const Spacer(),

                ElevatedButton(
                  onPressed: onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary500,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.neutral100,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // =========================
        // Image + Text (OVERLAPPING)
        // =========================
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.35, // controls overlap
          left: 24,
          right: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                image,
                width: 200,
                height: 500,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppTheme.neutral100),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      smallText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.neutral100,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}