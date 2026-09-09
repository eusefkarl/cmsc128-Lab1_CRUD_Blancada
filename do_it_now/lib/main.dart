import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/task_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DO IT NOW!',
      theme: ThemeData(
        fontFamily: 'Exo 2',
        textTheme: GoogleFonts.exo2TextTheme(ThemeData.light().textTheme),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF7D2DFF),
          onPrimary: Color(0xFFF3E8FF),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF0E1620),
          onSurface: Color(0xFFF0F6F8),
          error: Color(0xFFFF2D55),
        ),
        scaffoldBackgroundColor: const Color(0xFF05070A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E1620),
          foregroundColor: Color(0xFFF0F6F8),
          elevation: 0,
          shape: Border(bottom: BorderSide(color: Color(0xFF00E5FF), width: 1)),
          titleTextStyle: TextStyle(
            fontFamily: 'Exo 2',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFFF0F6F8),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF0A1018),
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF1D3140)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0A1018),
          labelStyle: const TextStyle(color: Color(0xFF5C7580)),
          floatingLabelStyle: const TextStyle(color: Color(0xFF00E5FF)),
          hintStyle: const TextStyle(color: Color(0xFF5C7580)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3D6B8A)),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF3D6B8A)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00E5FF), width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7D2DFF),
            foregroundColor: const Color(0xFFF3E8FF),
            textStyle: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFB889FF),
            textStyle: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(textStyle: GoogleFonts.exo2()),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF0E1620),
          titleTextStyle: GoogleFonts.exo2(
            color: const Color(0xFFF0F6F8),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: GoogleFonts.exo2(color: const Color(0xFFBFE6F5)),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF0E1620),
          contentTextStyle: TextStyle(
            color: Color(0xFFF0F6F8),
            fontFamily: 'Exo 2',
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF7D2DFF),
          foregroundColor: Color(0xFFF3E8FF),
        ),
        useMaterial3: true,
      ),
      home: const TaskHomePage(),
    );
  }
}
