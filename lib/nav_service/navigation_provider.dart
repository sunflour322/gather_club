import 'package:flutter/material.dart';

class NavigationProvider extends InheritedWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const NavigationProvider({
    Key? key,
    required this.onNavigate,
    required this.currentIndex,
    required Widget child,
  }) : super(key: key, child: child);

  static NavigationProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NavigationProvider>();
  }

  @override
  bool updateShouldNotify(NavigationProvider oldWidget) {
    return currentIndex != oldWidget.currentIndex;
  }
}
