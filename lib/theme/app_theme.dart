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
  static const glowBorder = Color(0x6638D9F5);
  static const purple = Color(0xFF7D2DFF);
  static const onPurple = Color(0xFFFFFFFF);
  static const highPriority = Color(0xFFFF819A);
  static const mediumPriority = Color(0xFFFFD27A);
  static const lowPriority = Color(0xFF77DC68);
  static const success = Color(0xFF63DCBC);
}

abstract final class AppFonts {
  /// Display face for headings, bundled under assets/fonts.
  static const display = 'Exo 2';
}

abstract final class AppRadii {
  /// Buttons, fields, badges and other small controls.
  static const double control = 4;

  /// Panels, cards, dialogs and notices.
  static const double panel = 6;
}

abstract final class AppShadows {
  /// The light of a System window against the dark canvas.
  static const glow = BoxShadow(color: Color(0x2238D9F5), blurRadius: 18);
}

abstract final class AppLayout {
  /// Keeps a task's actions within easy reach of its title on wide displays.
  static const double maxContentWidth = 960;
}

abstract final class AppFocus {
  /// Fills a focused dropdown, list row or tab, and rings a focused checkbox.
  static const fill = Color(0x6638D9F5);

  /// A ring around a button with keyboard focus. Material's default overlay is
  /// too faint on this dark theme to show where focus is.
  static WidgetStateProperty<BorderSide?> ring(
    Color color, [
    BorderSide? rest,
  ]) => WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.focused)
        ? BorderSide(color: color, width: 2)
        : rest,
  );
}

abstract final class AppButtonStyles {
  /// For the action that confirms losing something.
  static final danger = FilledButton.styleFrom(
    backgroundColor: AppColors.highPriority,
    foregroundColor: AppColors.canvas,
  );

  /// A filled button that gives way to the main action in the same section.
  static final secondary =
      FilledButton.styleFrom(
        backgroundColor: AppColors.raisedSurface,
        foregroundColor: AppColors.primaryText,
        disabledBackgroundColor: AppColors.raisedSurface,
        disabledForegroundColor: AppColors.secondaryText,
      ).copyWith(
        side: AppFocus.ring(
          AppColors.cyan,
          const BorderSide(color: AppColors.controlBorder),
        ),
      );
}

abstract final class AppTheme {
  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.cyan,
      onPrimary: AppColors.canvas,
      secondary: AppColors.purple,
      onSecondary: AppColors.onPurple,
      surface: AppColors.surface,
      onSurface: AppColors.primaryText,
      error: AppColors.highPriority,
      onError: AppColors.canvas,
    );
    final baseTextTheme = ThemeData.dark().textTheme.apply(
      bodyColor: AppColors.primaryText,
      displayColor: AppColors.primaryText,
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    );
    final windowShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.panel),
      side: const BorderSide(color: AppColors.glowBorder),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      focusColor: AppFocus.fill,
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
          fontFamily: AppFonts.display,
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
          borderRadius: BorderRadius.circular(AppRadii.panel),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryText,
        unselectedLabelColor: AppColors.secondaryText,
        labelStyle: const TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: AppColors.cyan,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.focused) ? AppFocus.fill : null,
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
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.controlBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.controlBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.cyan, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.highPriority),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.highPriority, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          backgroundColor: AppColors.cyan,
          foregroundColor: AppColors.canvas,
          disabledBackgroundColor: AppColors.raisedSurface,
          disabledForegroundColor: AppColors.secondaryText,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: controlShape,
        ).copyWith(side: AppFocus.ring(AppColors.primaryText)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: AppColors.primaryText,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
              shape: controlShape,
            ).copyWith(
              side: AppFocus.ring(
                AppColors.cyan,
                const BorderSide(color: AppColors.controlBorder),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          foregroundColor: AppColors.secondaryText,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: controlShape,
        ).copyWith(side: AppFocus.ring(AppColors.cyan)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.primaryText,
          shape: controlShape,
        ).copyWith(side: AppFocus.ring(AppColors.cyan)),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.secondaryText, width: 1.5),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.focused) ? AppFocus.fill : null,
        ),
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
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: windowShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.cyan,
        elevation: 8,
        titleTextStyle: const TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.primaryText,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(color: AppColors.secondaryText),
        shape: windowShape,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.cyan,
        elevation: 8,
        shape: windowShape,
        headerBackgroundColor: AppColors.raisedSurface,
        headerForegroundColor: AppColors.primaryText,
        headerHeadlineStyle: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        dividerColor: AppColors.divider,
        dayShape: WidgetStatePropertyAll(controlShape),
        todayBorder: const BorderSide(color: AppColors.cyan),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.secondaryText,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.cyan,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        shape: windowShape,
        dialBackgroundColor: AppColors.raisedSurface,
        hourMinuteShape: controlShape,
        dayPeriodShape: controlShape,
        dayPeriodBorderSide: const BorderSide(color: AppColors.controlBorder),
        dayPeriodColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.cyan
              : Colors.transparent,
        ),
        dayPeriodTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.canvas
              : AppColors.primaryText,
        ),
        helpTextStyle: const TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.cyan,
          fontWeight: FontWeight.w700,
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.secondaryText,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.cyan,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: const TextStyle(color: AppColors.primaryText),
        actionTextColor: AppColors.cyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
          side: const BorderSide(color: AppColors.cyan),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.panel)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cyan,
        linearTrackColor: AppColors.controlBorder,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.raisedSurface,
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
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
