import 'package:flutter/material.dart';
import 'package:gather_club/place_serice/place.dart';
import 'package:gather_club/user_service/user.dart';
import 'package:gather_club/user_service/friend.dart';
import 'package:gather_club/widgets/friends_bottom_sheet.dart';
import 'package:gather_club/user_service/friend_service.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/services/user_custom_place_service.dart';
import 'package:gather_club/place_serice/user_custom_place.dart';
import 'package:gather_club/pages/Example.dart';
import 'package:gather_club/nav_service/navigation_provider.dart';
import 'package:gather_club/services/user_service.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:gather_club/user_service/avatar_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:gather_club/widgets/custom_notification.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? _userData;
  List<UserCustomPlace> _userPlaces = [];
  List<Friend> _acceptedFriends = [];
  List<Friend> _incomingRequests = [];
  List<Friend> _outgoingRequests = [];
  bool _isLoading = true;
  int _starBalance = 0;
  late final FriendService _friendService;
  late final UserCustomPlaceService _userPlaceService;
  late final UserService _userService;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _friendService = FriendService(http.Client());
    _userPlaceService = UserCustomPlaceService(authProvider);
    _userService = UserService(authProvider);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      final userId = await authProvider.getUserId();

      if (token == null) {
        throw Exception('Не авторизован');
      }

      // Получаем данные текущего пользователя
      final response = await http.get(
        Uri.parse('http://212.67.8.92:8080/users/current'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Не удалось загрузить данные пользователя');
      }

      final userData = Map<String, dynamic>.from(json.decode(response.body));

      // Обновляем аватар в глобальном провайдере
      if (userData['avatarUrl'] != null) {
        Provider.of<AvatarProvider>(context, listen: false)
            .setAvatarUrl(userData['avatarUrl']);
      }

      // Получаем баланс звезд
      final balanceResponse = await http.get(
        Uri.parse('http://212.67.8.92:8080/users/$userId/currency/balance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (balanceResponse.statusCode == 200) {
        final balanceData = json.decode(balanceResponse.body);
        _starBalance = balanceData['balance'] ?? 0;
      }

      // Загружаем друзей, запросы и пользовательские места параллельно
      final futures = await Future.wait([
        _friendService.getAllFriends(token),
        _friendService.getIncomingRequests(token),
        _friendService.getOutgoingRequests(token),
        _userPlaceService.getAllPlaces(userId),
      ]);

      if (mounted) {
        setState(() {
          _userData = userData;
          _acceptedFriends = futures[0] as List<Friend>;
          _incomingRequests = futures[1] as List<Friend>;
          _outgoingRequests = futures[2] as List<Friend>;
          _userPlaces = futures[3] as List<UserCustomPlace>;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка загрузки данных: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _handleAcceptRequest(int friendshipId) async {
    try {
      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
      if (token == null) throw Exception('Не авторизован');

      final friend =
          await _friendService.acceptFriendRequest(friendshipId, token);

      if (mounted) {
        setState(() {
          _incomingRequests.removeWhere((f) => f.friendshipId == friendshipId);
          _acceptedFriends.add(friend);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка загрузки статистики: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _handleDeclineRequest(int friendshipId) async {
    try {
      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
      if (token == null) throw Exception('Не авторизован');

      await _friendService.rejectFriendRequest(friendshipId, token);

      if (mounted) {
        setState(() {
          _incomingRequests.removeWhere((f) => f.friendshipId == friendshipId);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка загрузки статистики: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _handleRemoveFriend(int friendshipId) async {
    try {
      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
      if (token == null) throw Exception('Не авторизован');

      await _friendService.deleteFriend(friendshipId, token);

      if (mounted) {
        setState(() {
          _acceptedFriends.removeWhere((f) => f.friendshipId == friendshipId);
        });

        CustomNotification.show(
          context,
          'Друг успешно удален',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка при удалении друга: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _updateAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final imageFile = File(image.path);
      final newAvatarUrl = await _userService.updateAvatar(imageFile);

      // Обновляем URL аватара в локальном состоянии
      setState(() {
        if (_userData != null) {
          _userData!['avatarUrl'] = newAvatarUrl;
        }
      });

      // Обновляем URL аватара в глобальном провайдере
      Provider.of<AvatarProvider>(context, listen: false)
          .setAvatarUrl(newAvatarUrl);

      if (mounted) {
        CustomNotification.show(
          context,
          'Аватар успешно обновлен',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          'Ошибка при обновлении аватара: $e',
        );
      }
    }
  }

  Widget _buildProfileHeader() {
    return Container(
      height: MediaQuery.of(context).size.height / 3,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.accentColor, AppTheme.accentColor.withOpacity(0.7)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: _userData?['avatarUrl'] != null
                    ? NetworkImage(_userData!['avatarUrl'])
                    : const AssetImage('assets/logo.png') as ImageProvider,
                onBackgroundImageError: (e, stackTrace) {
                  print('Ошибка загрузки аватара: $e');
                  // Если возникла ошибка загрузки аватара, сбрасываем URL
                  if (mounted) {
                    setState(() {
                      if (_userData != null) {
                        _userData!['avatarUrl'] = null;
                      }
                    });
                    // Также обновляем глобальный провайдер
                    Provider.of<AvatarProvider>(context, listen: false)
                        .setAvatarUrl(null);
                  }
                },
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _updateAvatar,
                    color: AppTheme.accentColor,
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _userData?['username'] ?? 'Загрузка...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_userData?['verified'] == true)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Подтвержден',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Информация о пользователе',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            _buildInfoRow(
                Icons.email, 'Email', _userData?['email'] ?? 'Не указан'),
            _buildInfoRow(
                Icons.calendar_today,
                'Дата регистрации',
                _userData?['createdAt'] != null
                    ? DateTime.parse(_userData!['createdAt'])
                        .toLocal()
                        .toString()
                        .split(' ')[0]
                    : 'Не указана'),
            const SizedBox(height: 8),
            if (_userData?['bio'] != null && _userData!['bio'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'О себе:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_userData!['bio']),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : 'Не указано',
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserPlacesSection() {
    if (_userPlaces.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Мои места',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final navigation = NavigationProvider.of(context);
                      if (navigation != null) {
                        navigation.onNavigate(0); // Индекс вкладки с картой
                      }
                    },
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Добавить'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'У вас пока нет сохранённых мест.\nДобавьте их через карту!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Мои места (${_userPlaces.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    final navigation = NavigationProvider.of(context);
                    if (navigation != null) {
                      navigation.onNavigate(0); // Индекс вкладки с картой
                    }
                  },
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Добавить'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _userPlaces.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final place = _userPlaces[index];
                return InkWell(
                  onTap: () {
                    try {
                      // Используем метод directBuildRoute для прямого построения маршрута
                      ExamplePage.directBuildRoute(
                          context, place.latitude, place.longitude, place.name);
                    } catch (e) {
                      print('Ошибка при построении маршрута: $e');

                      // Если произошла ошибка, пробуем через NavigationProvider
                      final navigation = NavigationProvider.of(context);
                      if (navigation != null) {
                        navigation
                            .onNavigate(0); // Сначала переключаем на карту
                        ExamplePage.navigateToLocation(
                          context,
                          place.latitude,
                          place.longitude,
                        );
                      }
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.place,
                          color: AppTheme.accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (place.description != null &&
                                place.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  place.description!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Координаты: ${place.latitude.toStringAsFixed(6)}, ${place.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map_outlined),
                        onPressed: () {
                          try {
                            // Используем метод directBuildRoute для прямого построения маршрута
                            ExamplePage.directBuildRoute(context,
                                place.latitude, place.longitude, place.name);
                          } catch (e) {
                            print('Ошибка при построении маршрута: $e');

                            // Если произошла ошибка, пробуем через NavigationProvider
                            final navigation = NavigationProvider.of(context);
                            if (navigation != null) {
                              navigation.onNavigate(
                                  0); // Сначала переключаем на карту
                              ExamplePage.navigateToLocation(
                                context,
                                place.latitude,
                                place.longitude,
                              );
                            }
                          }
                        },
                        tooltip: 'Показать на карте',
                        color: AppTheme.accentColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Статистика',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showFriendsBottomSheet,
                  icon: const Icon(Icons.people),
                  label: Text(
                    _incomingRequests.isNotEmpty
                        ? 'Друзья (${_acceptedFriends.length}) • ${_incomingRequests.length}'
                        : 'Друзья (${_acceptedFriends.length})',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('12', 'Встреч'),
                _buildStatItem('${_acceptedFriends.length}', 'Друзей'),
                _buildStatItem('${_userPlaces.length}', 'Мест'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        if (label == 'Встреч')
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/star.png',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 4),
              Text(
                _starBalance.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentColor,
                ),
              ),
            ],
          )
        else
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentColor,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _showFriendsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) => FriendsBottomSheet(
            friends: [
              ..._acceptedFriends,
              ..._incomingRequests,
              ..._outgoingRequests
            ],
            onRemoveFriend: _handleRemoveFriend,
            onAcceptRequest: _handleAcceptRequest,
            onDeclineRequest: _handleDeclineRequest,
            onAddFriend: () {
              Navigator.of(context).pushNamed('/friends/search');
            },
            onFriendsUpdated: _loadUserData,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildProfileHeader(),
              _buildUserInfoSection(),
              _buildStatsSection(),
              _buildUserPlacesSection(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade700],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        try {
                          final authProvider =
                              Provider.of<AuthProvider>(context, listen: false);
                          await authProvider.logout();
                          if (mounted) {
                            // Очищаем состояние
                            setState(() {
                              _userData = null;
                              _userPlaces = [];
                              _acceptedFriends = [];
                              _incomingRequests = [];
                              _outgoingRequests = [];
                            });
                            // Перенаправляем на страницу логина
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isLoading = false);
                            CustomNotification.show(
                              context,
                              'Ошибка при выходе: $e',
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Выйти из аккаунта',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
