import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFF080C14);
  static const surface = Color(0xFF111B2B);
  static const raisedSurface = Color(0xFF172337);
  static const primaryText = Color(0xFFF3F6FC);
  static const secondaryText = Color(0xFFA7B7CB);
  static const divider = Color(0xFF2A3B51);
  static const controlBorder = Color(0xFF56748E);
  static const cyan = Color(0xFF38D9F5);
  static const purple = Color(0xFF7D2DFF);
  static const onPurple = Color(0xFFFFFFFF);
  static const highPriority = Color(0xFFFF819A);
  static const mediumPriority = Color(0xFFFFD27A);
  static const lowPriority = Color(0xFF77DC68);
  static const success = Color(0xFF63DCBC);
}

abstract final class AppTheme {
  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.purple,
      onPrimary: AppColors.onPurple,
      secondary: AppColors.cyan,
      onSecondary: AppColors.canvas,
      surface: AppColors.surface,
      onSurface: AppColors.primaryText,
      error: AppColors.highPriority,
      onError: AppColors.canvas,
    );
    final baseTextTheme = ThemeData.dark().textTheme.apply(
      bodyColor: AppColors.primaryText,
      displayColor: AppColors.primaryText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: baseTextTheme,
      dividerColor: AppColors.divider,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: AppColors.divider)),
        titleTextStyle: TextStyle(
          fontFamily: 'Exo 2',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryText,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.raisedSurface,
        labelStyle: const TextStyle(color: AppColors.secondaryText),
        floatingLabelStyle: const TextStyle(color: AppColors.cyan),
        hintStyle: const TextStyle(color: AppColors.secondaryText),
        helperStyle: const TextStyle(color: AppColors.secondaryText),
        errorStyle: const TextStyle(color: AppColors.highPriority),
        suffixIconColor: AppColors.primaryText,
        iconColor: AppColors.primaryText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.controlBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.controlBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.cyan, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.highPriority),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.highPriority, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          backgroundColor: AppColors.purple,
          foregroundColor: AppColors.onPurple,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          foregroundColor: AppColors.primaryText,
          side: const BorderSide(color: AppColors.controlBorder),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          foregroundColor: AppColors.secondaryText,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.primaryText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.secondaryText, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.cyan;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.canvas),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: AppColors.primaryText),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontFamily: 'Exo 2',
          color: AppColors.primaryText,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(color: AppColors.secondaryText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: AppColors.primaryText),
        actionTextColor: AppColors.cyan,
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.purple,
        foregroundColor: AppColors.onPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cyan,
        linearTrackColor: AppColors.raisedSurface,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.raisedSurface,
          borderRadius: BorderRadius.all(Radius.circular(6)),
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.controlBorder),
          ),
        ),
        textStyle: TextStyle(color: AppColors.primaryText),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.secondaryText,
        textColor: AppColors.primaryText,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
