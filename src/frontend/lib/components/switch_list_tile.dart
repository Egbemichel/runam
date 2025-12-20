import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:runam/app/theme.dart';

class ProfileSwitchListTile extends StatefulWidget {
  const ProfileSwitchListTile({super.key});

  @override
  State<ProfileSwitchListTile> createState() => _ProfileSwitchListTileState();
}

class _ProfileSwitchListTileState extends State<ProfileSwitchListTile> {
  // false means manual entry is visible
  bool _useCurrentLocation = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header with ListTile to isolate the Switch
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Use your current location',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.primary700,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: Switch.adaptive(
            value: _useCurrentLocation,
            activeColor: AppTheme.primary700,
            onChanged: (bool value) {
              setState(() {
                _useCurrentLocation = value;
              });
            },
          ),
        ),

        // 2. Animated section for the TextField
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _useCurrentLocation
              ? const SizedBox(width: double.infinity) // Hidden when toggle is ON
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Pill-shaped location input
              // Add Mapbox search listener
              TextField(
                decoration: InputDecoration(
                  hintText: 'Enter your preferred location',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  suffixIcon: const Icon(
                    IconsaxPlusLinear.gps,
                    color: Colors.grey,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Instructional text
              Text(
                'This location is the same which runners will deliver to and get paid at for round-trip errands.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}