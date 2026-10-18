import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 21, 105, 56),
    ),
    scaffoldBackgroundColor: const Color.fromARGB(255, 215, 233, 252),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
  );
}
