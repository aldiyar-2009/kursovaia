import 'package:flutter/material.dart';

/// Stealth Dark / Midnight Slate palette.
abstract final class AppColors {
  // Surfaces
  static const background = Color(0xFF0C0D11);
  static const surface = Color(0xFF15171E);
  static const elevated = Color(0xFF1E212B);
  static const border = Color(0xFF272A36);

  // Text
  static const textPrimary = Color(0xFFF3F4F8);
  static const textSecondary = Color(0xFF8F94A6);
  static const textMuted = Color(0xFF5D6273);

  // Accents
  static const accent = Color(0xFF6366F1); // electric indigo
  static const accentCyan = Color(0xFF06B6D4); // muted neon cyan

  // Lesson types
  static const lecture = Color(0xFF3B82F6);
  static const practice = Color(0xFFF59E0B);
  static const lab = Color(0xFF10B981);

  // Status
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static const p2 = Color(0xFFF97316);
  static const p3 = Color(0xFF3B82F6);

  /// 12% tinted plate used behind coloured labels.
  static Color plate(Color c, [double opacity = 0.12]) => c.withValues(alpha: opacity);

  static Color lessonType(String type) => switch (type) {
        'practice' => practice,
        'lab' => lab,
        _ => lecture,
      };

  static Color priority(int p) => switch (p) {
        1 => danger,
        2 => p2,
        _ => p3,
      };

  /// Parses `#RRGGBB` / `#AARRGGBB`; falls back to [accent].
  static Color fromHex(String? hex) {
    if (hex == null) return accent;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? accent : Color(v);
  }

  static String toHex(Color c) {
    final argb = c.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Palette offered in the subject colour picker.
  static const subjectPalette = <Color>[
    Color(0xFF6366F1),
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFF84CC16),
    Color(0xFFF59E0B),
    Color(0xFFF97316),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
  ];
}
