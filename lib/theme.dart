import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette derived from the physical instrument: warm dark wood body,
/// mother-of-pearl keys, brass hardware.
class Palette {
  static const bg = Color(0xFF1B1517); // fondo
  static const panel = Color(0xFF241D1F); // pannello
  static const brass = Color(0xFFC8A45A); // ottone
  static const brassDim = Color(0xFF7D6836);
  static const brassDeep = Color(0xFF4A3D1F);
  static const ivory = Color(0xFFECE3D6); // avorio testo
  static const muted = Color(0xFFA99B88);
  static const line = Color(0xFF3A2F31);

  // Mother-of-pearl white keys
  static const whiteTop = Color(0xFFFBF7EF);
  static const whiteMid = Color(0xFFF2E9D9);
  static const whiteBot = Color(0xFFE7DCC7);

  // Ebony black keys
  static const blackTop = Color(0xFF3A3033);
  static const blackMid = Color(0xFF1A1315);
  static const blackBot = Color(0xFF0D0809);
}

/// Space Mono for notes / annotation.
TextStyle mono({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = Palette.ivory,
  double spacing = 0,
  double? height,
}) =>
    GoogleFonts.spaceMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
    );

/// Fraunces for titles.
TextStyle display({
  double size = 22,
  FontWeight weight = FontWeight.w600,
  Color color = Palette.ivory,
}) =>
    GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: Palette.brass,
      surface: Palette.panel,
      onSurface: Palette.ivory,
    ),
    splashColor: Palette.brassDim.withValues(alpha: 0.15),
    highlightColor: Palette.brassDim.withValues(alpha: 0.10),
  );
}
