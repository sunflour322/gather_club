import 'package:flutter/material.dart';
import 'package:gather_club/Example.dart';
import 'package:gather_club/user_service/user_repo.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:http/http.dart' as http;

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
  String? _avatarUrl;
  final AuthProvider _authProvider = AuthProvider();
  final http.Client _client = http.Client();
  late final UserRepository _userRepository =
      UserRepository(_client, _authProvider);

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
  }

  Future<void> _loadUserAvatar() async {
    try {
      final userId = await _userRepository.getCurrentUserId();
      if (userId != null) {
        final avatarUrl = await _userRepository.getUserAvatarUrl(userId);
        print('Avatar URL: $avatarUrl'); // Добавим лог для отладки
        setState(() {
          _avatarUrl = avatarUrl;
        });
      }
    } catch (e) {
      print('Error loading avatar: $e');
    }
  }

  Future<String?> _fetchAvatarUrl(int userId) async {
    final token = await _authProvider.getToken();
    final response = await _client.get(
      Uri.parse('http://212.67.8.92:8080/users/$userId/avatar'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      print(response.body);
      return response.body;
    } else {
      print('Failed to load avatar: ${response.statusCode}');
      return null;
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(5.0),
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
                      backgroundImage: _avatarUrl != null
                          ? NetworkImage(_avatarUrl!)
                          : const AssetImage('assets/logo.png')
                              as ImageProvider,
                      onBackgroundImageError: (e, stack) {
                        print('Failed to load avatar: $e');
                        setState(() {
                          _avatarUrl = null;
                        });
                      },
                      radius: 16,
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
