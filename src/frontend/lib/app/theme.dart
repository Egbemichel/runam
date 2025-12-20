import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class AppTheme {
  // Colors from your Figma file
  static const Color primary500 = Color(0xFF8E70EF);
  static const Color primary700 = Color(0xFF16056B);

  static const Color secondary500 = Color(0xFF9EF0FF);
  static Color secondary300 = Color(0x1A9EF0FF);

  static const Color neutral200 = Color(0xFF656262);
  static const Color neutral100 = Color(0xFFFFFFFF);


  static const Color success = Color(0xFF038A08);
  static const Color warning = Color(0xFFCAB601);
  static const Color error = Color(0xFFFF1515);
  static const Color links = Color(0xFF1976F0);

  // THEME
  static final ThemeData theme = ThemeData.light(
    // Basic color assignments only — nothing added


    useMaterial3: true,
  ).copyWith(
    // scaffoldBackgroundColor: neutral100,
    colorScheme: ColorScheme.fromSeed(seedColor: primary700),

    appBarTheme: AppBarTheme(
      scrolledUnderElevation: 0,
    ),

    textTheme: GoogleFonts.shantellSansTextTheme(),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: primary700,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8.0),
              color: AppTheme.neutral100,
          ),
          child: Icon(IconsaxPlusLinear.arrow_left_1),
        );
      },
    )
  );
}
