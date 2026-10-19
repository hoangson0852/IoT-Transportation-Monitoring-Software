import 'package:flutter/material.dart';

class AppColors {
  // === BACKGROUNDS ===
  static const Color background = Color(0xFF0A0E1A);     // Deep navy black
  static const Color surface = Color(0xFF111827);         // Card surface
  static const Color surfaceLight = Color(0xFF1F2937);    // Lighter card
  static const Color surfaceBorder = Color(0xFF374151);   // Border

  // === PRIMARY BRAND ===
  static const Color primary = Color(0xFF1D4ED8);        // Military blue
  static const Color primaryLight = Color(0xFF3B82F6);   // Hover/accent
  static const Color primaryGlow = Color(0x331D4ED8);    // Blue glow

  // === STATUS COLORS ===
  static const Color success = Color(0xFF16A34A);        // Operational green
  static const Color successLight = Color(0x2216A34A);   // Green tint
  static const Color warning = Color(0xFFF59E0B);        // Amber / attention
  static const Color warningLight = Color(0x22F59E0B);   // Amber tint
  static const Color danger = Color(0xFFDC2626);         // Alert red
  static const Color dangerLight = Color(0x22DC2626);    // Red tint
  static const Color offline = Color(0xFF6B7280);        // Offline grey

  // === TEXT ===
  static const Color textPrimary = Color(0xFFF9FAFB);    // White text
  static const Color textSecondary = Color(0xFF9CA3AF);  // Muted text
  static const Color textMuted = Color(0xFF6B7280);      // Very muted

  // === GRADIENTS ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
