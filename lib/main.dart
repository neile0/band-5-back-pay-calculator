import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'calculator_page.dart';

const _teal = Color(0xFF005C69);
const _gold = Color(0xFFFFC837);
const _charcoal = Color(0xFF1E2D32);
const _cream = Color(0xFFF1F7F7);

void main() {
  runApp(const BackPayApp());
}

class BackPayApp extends StatelessWidget {
  const BackPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _teal,
        primary: _teal,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: _cream,
      useMaterial3: true,
      cardTheme: const CardThemeData(
        surfaceTintColor: Colors.transparent,
        color: Colors.white,
        elevation: 0,
      ),
    );

    return MaterialApp(
      title: 'NHS Scotland Band 5 Back Pay Calculator',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
          bodyColor: _charcoal,
          displayColor: _charcoal,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: _charcoal,
            textStyle: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _charcoal,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: _teal,
          inactiveTrackColor: const Color(0xFFCCEDE9),
          thumbColor: _teal,
          overlayColor: _teal.withValues(alpha: 0.12),
          trackHeight: 4,
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),
      home: const CalculatorPage(),
    );
  }
}
