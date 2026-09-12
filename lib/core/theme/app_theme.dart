import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);
  static ThemeData _theme(Brightness b) {
    final isLight = b == Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xff0b3d3a),
          brightness: b,
        ).copyWith(
          primary: isLight ? const Color(0xff0b3d3a) : const Color(0xff8bc8bd),
          secondary: const Color(0xffcda45e),
          surface: isLight ? const Color(0xfff8f5ee) : const Color(0xff101c1c),
          primaryContainer: isLight
              ? const Color(0xffd6e6df)
              : const Color(0xff173b38),
          secondaryContainer: isLight
              ? const Color(0xffffe6b6)
              : const Color(0xff4d3d20),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight
          ? const Color(0xfff3ebdd)
          : const Color(0xff071521),
      cardTheme: CardThemeData(
        color: isLight ? const Color(0xfffaf7f0) : const Color(0xff122526),
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isLight ? const Color(0x1f0b3d3a) : const Color(0x24ffffff),
          ),
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight
            ? const Color(0xfff8f5ee)
            : const Color(0xff0b1d21),
        indicatorColor: isLight
            ? const Color(0xffd6e6df)
            : const Color(0xff21453f),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: isLight ? const Color(0xff173b38) : const Color(0xffd8e8e4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? const Color(0xffe8e0d2)
            : const Color(0xff17302f),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(height: 1.45),
      ),
    );
  }
}
