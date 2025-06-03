import 'package:flutter/material.dart';

class AppTheme {
  // Основной цвет (белый)
  static const Color primaryColor = Colors.white;

  // Дополнительные цвета
  static const Color secondaryColor = Colors.black;
  static const Color accentColor =
      Color.fromARGB(255, 38, 133, 109); // Мятный цвет

  // Нейтральные цвета для текста и других элементов
  static const Color textPrimaryColor = Colors.black;
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color dividerColor = Color(0xFFEEEEEE);

  // Цвета состояний
  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF43A047);
  static const Color warningColor = Color(0xFFFFA000);

  // Цвета для кнопок
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: accentColor,
    foregroundColor: secondaryColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
    ),
  );

  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: accentColor,
    side: const BorderSide(color: accentColor),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
    ),
  );

  // Определение светлой темы
  static ThemeData lightTheme = ThemeData(
    // Основные цвета
    primaryColor: primaryColor,
    scaffoldBackgroundColor: primaryColor,
    colorScheme: const ColorScheme.light(
      primary: accentColor,
      secondary: secondaryColor,
      surface: primaryColor,
      background: primaryColor,
      error: errorColor,
    ),

    // Настройки AppBar
    appBarTheme: const AppBarTheme(
      color: primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: secondaryColor),
      titleTextStyle: TextStyle(
        color: textPrimaryColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Настройки текста
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textPrimaryColor),
      displayMedium: TextStyle(color: textPrimaryColor),
      displaySmall: TextStyle(color: textPrimaryColor),
      headlineMedium: TextStyle(color: textPrimaryColor),
      headlineSmall: TextStyle(color: textPrimaryColor),
      titleLarge: TextStyle(color: textPrimaryColor),
      titleMedium: TextStyle(color: textPrimaryColor),
      titleSmall: TextStyle(color: textPrimaryColor),
      bodyLarge: TextStyle(color: textPrimaryColor),
      bodyMedium: TextStyle(color: textPrimaryColor),
      bodySmall: TextStyle(color: textSecondaryColor),
      labelLarge: TextStyle(color: textPrimaryColor),
    ),

    // Настройки кнопок
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primaryButtonStyle,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: secondaryButtonStyle,
    ),

    // Настройки карточек
    cardTheme: CardTheme(
      color: primaryColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Настройки поля ввода
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),

    // Настройки нижней навигации
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: primaryColor,
      selectedItemColor: accentColor,
      unselectedItemColor: textSecondaryColor,
    ),

    // Настройки TabBar
    tabBarTheme: const TabBarTheme(
      labelColor: accentColor,
      unselectedLabelColor: Color.fromARGB(255, 228, 3, 3),
      indicator: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: accentColor,
            width: 2.0,
          ),
        ),
      ),
    ),

    // Настройки для плавающей кнопки
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: primaryColor,
    ),

    // Настройки для диалогов
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
