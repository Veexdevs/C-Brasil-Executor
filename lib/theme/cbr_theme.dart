import 'package:flutter/material.dart';

import '../cbr/cbr.dart';

/// Paleta do C Brasil em preto, com verde vivo.
abstract final class CbrColors {
  static const Color background = Color(0xFF000000);
  static const Color backgroundDeep = Color(0xFF000000);
  static const Color surface = Color(0xFF000000);
  static const Color surfaceAlt = Color(0xFF000000);
  static const Color surfaceRaised = Color(0xFF111111);
  static const Color border = Color(0xFF252525);
  static const Color borderStrong = Color(0xFF3A3A3A);

  static const Color text = Color(0xFFF5F5F5);
  static const Color textMuted = Color(0xFFA6A6A6);
  static const Color textFaint = Color(0xFF777777);

  static const Color green = Color(0xFF00E676);
  static const Color greenBright = Color(0xFF00FF66);
  static const Color greenDeep = Color(0xFF00A344);
  static const Color yellow = Color(0xFFFFD600);
  static const Color yellowSoft = Color(0xFFFFEA70);
  static const Color blue = Color(0xFF4FA8FF);
  static const Color blueDeep = Color(0xFF1B5C99);

  static const Color codeText = Color(0xFFDBEDF2);
  static const Color codeKeyword = Color(0xFF6CBBFF);
  static const Color codeType = Color(0xFF00FF66);
  static const Color codeBuiltin = Color(0xFFFFD166);
  static const Color codeFunction = Color(0xFFBFE3FF);
  static const Color codeString = Color(0xFFE6C86E);
  static const Color codeNumber = Color(0xFF80C8FF);
  static const Color codeComment = Color(0xFF5F7B88);
  static const Color codeOperator = Color(0xFF7FA7B8);
  static const Color codeMarker = Color(0xFF00FF66);
}

/// Fontes monoespaçadas com fallback para todas as plataformas.
const List<String> kMonoFallback = <String>[
  'JetBrains Mono',
  'Fira Code',
  'Cascadia Mono',
  'Menlo',
  'Consolas',
  'DejaVu Sans Mono',
  'Roboto Mono',
  'monospace',
];

const List<String> kSansFallback = <String>[
  'Inter',
  'Segoe UI',
  'Roboto',
  'Helvetica Neue',
  'Arial',
];

abstract final class CbrTextStyles {
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: kMonoFallback,
    fontSize: 14,
    height: 1.6,
    color: CbrColors.codeText,
    letterSpacing: 0.1,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: kSansFallback,
    fontSize: 14,
    height: 1.55,
    color: CbrColors.text,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: kSansFallback,
    fontSize: 13.5,
    height: 1.5,
    color: CbrColors.textMuted,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: kSansFallback,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.8,
    color: CbrColors.text,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: kSansFallback,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: CbrColors.text,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: kSansFallback,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: CbrColors.textMuted,
  );
}

/// Estilo de cada categoria de token do editor.
TextStyle styleForToken(CbrTokenStyle style, double fontSize) {
  final base = CbrTextStyles.mono.copyWith(fontSize: fontSize);
  switch (style) {
    case CbrTokenStyle.keyword:
      return base.copyWith(color: CbrColors.codeKeyword, fontWeight: FontWeight.w600);
    case CbrTokenStyle.type:
      return base.copyWith(color: CbrColors.codeType, fontWeight: FontWeight.w600);
    case CbrTokenStyle.builtin:
      return base.copyWith(color: CbrColors.codeBuiltin);
    case CbrTokenStyle.function:
      return base.copyWith(color: CbrColors.codeFunction);
    case CbrTokenStyle.text:
      return base.copyWith(color: CbrColors.codeString);
    case CbrTokenStyle.number:
      return base.copyWith(color: CbrColors.codeNumber);
    case CbrTokenStyle.comment:
      return base.copyWith(color: CbrColors.codeComment, fontStyle: FontStyle.italic);
    case CbrTokenStyle.operator:
      return base.copyWith(color: CbrColors.codeOperator);
    case CbrTokenStyle.punctuation:
      return base.copyWith(color: CbrColors.codeOperator);
    case CbrTokenStyle.marker:
      return base.copyWith(
        color: CbrColors.codeMarker,
        fontWeight: FontWeight.w600,
      );
    case CbrTokenStyle.identifier:
      return base.copyWith(color: CbrColors.codeText);
  }
}

ThemeData buildCbrTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CbrColors.green,
    brightness: Brightness.dark,
  ).copyWith(
    primary: CbrColors.green,
    onPrimary: const Color(0xFF04231A),
    secondary: CbrColors.yellow,
    tertiary: CbrColors.blue,
    surface: CbrColors.surface,
    error: CbrColors.yellow,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: CbrColors.background,
    iconTheme: const IconThemeData(color: Colors.white),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Colors.white),
    ),
    fontFamily: 'Inter',
    fontFamilyFallback: kSansFallback,
    dividerColor: CbrColors.border,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(
      headlineLarge: CbrTextStyles.headline,
      titleMedium: CbrTextStyles.title,
      bodyMedium: CbrTextStyles.body,
      bodySmall: CbrTextStyles.bodyMuted,
      labelSmall: CbrTextStyles.label,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: CbrColors.surfaceAlt,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CbrColors.surfaceRaised,
      contentTextStyle: CbrTextStyles.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: CbrColors.surfaceRaised),
      textStyle: TextStyle(color: CbrColors.text, fontSize: 12),
      waitDuration: Duration(milliseconds: 400),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: CbrColors.greenBright,
      selectionColor: Color(0x5500FF66),
      selectionHandleColor: CbrColors.green,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CbrColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: CbrColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: CbrColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: CbrColors.green, width: 1.4),
      ),
      hintStyle: CbrTextStyles.bodyMuted,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(
        CbrColors.borderStrong.withValues(alpha: 0.9),
      ),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(8),
    ),
  );
}
