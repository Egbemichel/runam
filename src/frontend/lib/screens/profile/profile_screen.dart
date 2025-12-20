import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../app/theme.dart';
import '../../components/switch_list_tile.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const String routeName = "profile";
  static const String path = '/profile';

  final bool switchValue1 = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          // Inside ProfileScreen -> ListView
          Hero(
            tag: 'ghost-avatar-hero', // Exact match to the Home screen tag
            child: CircleAvatar(
              radius: 105,
              backgroundColor: Colors.transparent, // Ensure background doesn't flicker
              child: Image.asset(
                'assets/images/ghost_2.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                decoration: BoxDecoration(
                  color: AppTheme.secondary300,
                  border: Border.all(
                    width: 1,
                    color: AppTheme.secondary300,
                  ),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: ProfileSwitchListTile(),
              ),
              Positioned(
                top: -20,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary500,
                    border: Border.all(
                      width: 2,
                      color: AppTheme.neutral100,
                    ),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Image.asset('assets/images/cancel.png', fit: BoxFit.cover),
                ),
              ),
            ],
          ),
          ListTile(
              leading: Icon(
                  IconsaxPlusLinear.shield,
                  color: AppTheme.primary700,
              ),
              title: Text(
                "Trust & safety",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary700,
                ),
              ),
              trailing: Icon(
                  IconsaxPlusLinear.arrow_right_3,
                  color: AppTheme.primary700,
              )
          ),
          ListTile(
              leading: Icon(
                  IconsaxPlusLinear.people,
                  color: AppTheme.primary700,
              ),
              title: Text(
                "How buyers & runners interact",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary700,
                ),
              ),
              trailing: Icon(
                  IconsaxPlusLinear.arrow_right_3,
                  color: AppTheme.primary700,
              )
          ),
        ],
      ),
    );
  }
}
