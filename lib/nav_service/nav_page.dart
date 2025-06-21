import 'package:flutter/material.dart';
import 'package:gather_club/pages/Example.dart';
import 'package:gather_club/pages/account_page.dart';
import 'package:gather_club/pages/chat_page.dart';
import 'package:gather_club/api_services/user_service/user_repo.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
import 'package:gather_club/nav_service/navigation_provider.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:gather_club/api_services/user_service/avatar_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class NavPage extends StatefulWidget {
  const NavPage({super.key});

  @override
  State<NavPage> createState() => _NavPageState();
}

class _NavPageState extends State<NavPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _widgetOptions = [
    ExamplePage(),
    const ChatPage(),
    const AccountPage(),
  ];

  String? _avatarUrl;
  final AuthProvider _authProvider = AuthProvider();
  final http.Client _client = http.Client();
  late final UserRepository _userRepository =
      UserRepository(_client, _authProvider);

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
    _setUserOnline();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _setUserOffline();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline();
    } else if (state == AppLifecycleState.paused) {
      _setUserOffline();
    }
  }

  Future<void> _setUserOnline() async {
    try {
      await _userRepository.setUserOnline();
      print('Пользователь переведен в статус онлайн');
    } catch (e) {
      print('Ошибка при изменении статуса пользователя: $e');
    }
  }

  Future<void> _setUserOffline() async {
    try {
      await _userRepository.setUserOffline();
      print('Пользователь переведен в статус офлайн');
    } catch (e) {
      print('Ошибка при изменении статуса пользователя: $e');
    }
  }

  void _onTabChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _loadUserAvatar() async {
    try {
      final userId = await _userRepository.getCurrentUserId();
      if (userId != null && mounted) {
        final avatarUrl = await _userRepository.getUserAvatarUrl(userId);
        if (mounted) {
          setState(() {
            _avatarUrl = avatarUrl;
          });
          Provider.of<AvatarProvider>(context, listen: false)
              .setAvatarUrl(avatarUrl);
        }
      }
    } catch (e) {
      debugPrint('Error loading avatar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationProvider(
      currentIndex: _selectedIndex,
      onNavigate: _onTabChange,
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: IndexedStack(
          index: _selectedIndex,
          children: _widgetOptions,
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  color: Colors.black.withOpacity(0.3),
                )
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
                child: GNav(
                  rippleColor: Colors.grey[800]!,
                  hoverColor: Colors.grey[700]!,
                  gap: 8,
                  activeColor: Colors.white,
                  iconSize: 24,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  duration: const Duration(milliseconds: 400),
                  tabBackgroundColor: AppTheme.accentColor.withOpacity(0.2),
                  color: Colors.white,
                  tabs: [
                    const GButton(
                      icon: Icons.map_outlined,
                      text: 'Карта',
                      textSize: 30,
                      iconSize: 30,
                    ),
                    const GButton(
                      icon: Icons.chat_outlined,
                      text: 'Чаты',
                      textSize: 30,
                      iconSize: 30,
                    ),
                    GButton(
                      icon: Icons.account_circle_outlined,
                      text: 'Профиль',
                      leading: Consumer<AvatarProvider>(
                        builder: (context, avatarProvider, _) {
                          final avatarUrl =
                              avatarProvider.avatarUrl ?? _avatarUrl;
                          return CircleAvatar(
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : const AssetImage('assets/logo.png')
                                    as ImageProvider,
                            onBackgroundImageError: (e, stack) {
                              print('Failed to load avatar: $e');
                              setState(() {
                                _avatarUrl = null;
                              });
                              Provider.of<AvatarProvider>(context,
                                      listen: false)
                                  .setAvatarUrl(null);
                            },
                            radius: 16,
                          );
                        },
                      ),
                    ),
                  ],
                  selectedIndex: _selectedIndex,
                  onTabChange: _onTabChange,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
