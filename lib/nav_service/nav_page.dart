import 'package:flutter/material.dart';
import 'package:gather_club/Example.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class NavPage extends StatefulWidget {
  const NavPage({super.key});

  @override
  State<NavPage> createState() => _NavPageState();
}

int _selectedIndex = 0;
final _widgetOptions = [
  const ExamplePage(),
  const ExamplePage(),
  const ExamplePage(),
];

class _NavPageState extends State<NavPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: _widgetOptions.elementAt(_selectedIndex),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black.withOpacity(.1),
              )
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
              child: GNav(
                rippleColor: Colors.grey[300]!,
                hoverColor: Colors.grey[100]!,
                gap: 8,
                activeColor: Colors.black,
                iconSize: 24,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                duration: const Duration(milliseconds: 400),
                tabBackgroundColor: Colors.grey[100]!,
                color: Colors.black,
                tabs: [
                  const GButton(
                    icon: Icons.home_filled,
                    text: 'Главное',
                    textSize: 30,
                    iconSize: 30,
                  ),
                  const GButton(
                    icon: Icons.note,
                    text: 'Цели',
                    textSize: 30,
                    iconSize: 30,
                  ),
                  GButton(
                    icon: Icons.account_circle_outlined,
                    text: 'Профиль',
                    leading: CircleAvatar(
                        // backgroundImage: avatarPath != null
                        //     ? NetworkImage(avatarPath!) // Загружаем аватар из URL
                        //     : const AssetImage('assets/nix.png')
                        //         as ImageProvider, // Локальное изображение
                        // radius: 16,
                        ),
                  ),
                ],
                selectedIndex: _selectedIndex,
                onTabChange: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
