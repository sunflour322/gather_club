import 'package:flutter/material.dart';
import 'package:gather_club/theme/app_theme.dart';

// Базовый шаблон для новой страницы навигации
class NavPage extends StatefulWidget {
  const NavPage({super.key});

  @override
  State<NavPage> createState() => _NavPageState();
}

class _NavPageState extends State<NavPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Навигация'),
      ),
      body: const Center(
        child: Text('Содержимое страницы'),
      ),
    );
  }
}
