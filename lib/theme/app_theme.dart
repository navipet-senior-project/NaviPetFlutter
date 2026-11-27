import 'package:flutter/material.dart';

/// Design tokens ported 1:1 from the React Native app's `theme/index.ts`.
/// These are the single source of truth for colors, spacing, radii and shadows.
class AppColors {
  AppColors._();

  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFFFFB000);
  static const accentDark = Color(0xFFF97316);
  static const accentSoft = Color(0xFFFFF1C7);
  static const ink = Color(0xFF182033);
  static const muted = Color(0xFF667085);
  static const faint = Color(0xFF98A2B3);
  static const line = Color(0xFFEAECF0);
  static const map = Color(0xFFF4F7F2);
  static const mapStreet = Color(0xFFDCE7DC);
  static const teal = Color(0xFF0EA5A4);
  static const blue = Color(0xFF2F80ED);
  static const green = Color(0xFF18A058);
  static const danger = Color(0xFFD92D20);
  static const shadow = Color(0xFF101828);

  // Sign-in screen literals (kept verbatim from SignInScreen.tsx).
  static const signInBg = Color(0xFFF8F9FA);
  static const navy = Color(0xFF002B5B);
  static const amber = Color(0xFFFEB700);
  static const amberInk = Color(0xFF6B4B00);
  static const inputBorder = Color(0xFFC4C6D0);
  static const labelInk = Color(0xFF43474F);
  static const fieldIcon = Color(0xFF747780);

  // Figma literals for the cloned screens (Pet / Checklist / Search /
  // Account / AR). Kept verbatim from the design file.
  static const petInk = Color(0xFF00244E); // dark navy headings/text
  static const yellow = Color(0xFFFDCC00); // primary accent fill
  static const addBtn = Color(0xFFFECB00); // Add Account / Active pill
  static const yellowInk = Color(0xFF6E5700); // text on yellow
  static const gemInk = Color(0xFF735C00); // gem reward text
  static const cardBorder = Color(0xFFE2E2E2);
  static const pinOrange = Color(0xFFF5A623); // map pin / paw FAB
  static const accountTitle = Color(0xFF1E1B4B);
  static const accountLabel = Color(0xFF1A1A40);
  static const subtext = Color(0xFF8483A4);
  static const taskInk = Color(0xFF1A1C1C);
  static const divider = Color(0xFFF1F5F9);
  static const screenBg = Color(0xFFF9F9F9); // pet/list/search page bg
  static const accountBg = Color(0xFFF4F4F7);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;
}

class AppShadows {
  AppShadows._();

  /// Mirrors `shadows.card` from the RN theme.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14101828), // shadow @ 0.08 opacity
      offset: Offset(0, 10),
      blurRadius: 20,
    ),
  ];

  /// Mirrors `shadows.soft` from the RN theme.
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0F101828), // shadow @ 0.06 opacity
      offset: Offset(0, 6),
      blurRadius: 14,
    ),
  ];
}
