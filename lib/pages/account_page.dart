import 'package:flutter/material.dart';
import 'package:gather_club/place_serice/place.dart';
import 'package:gather_club/user_service/user.dart';
import 'package:gather_club/user_service/friend.dart';
import 'package:gather_club/user_service/friends_bottom_sheet.dart';
import 'package:gather_club/user_service/friend_service.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? _userData;
  List<Place> _userPlaces = [];
  List<Friend> _friends = [];
  bool _isLoading = true;
  late final FriendService _friendService;

  @override
  void initState() {
    super.initState();
    _friendService = FriendService(http.Client());
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
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

      // Загружаем друзей и запросы параллельно
      final friends = await _friendService.getAllFriends(token);
      final incomingRequests = await _friendService.getIncomingRequests(token);
      final outgoingRequests = await _friendService.getOutgoingRequests(token);

      print('Loaded friends: $friends');
      print('Loaded incoming requests: $incomingRequests');
      print('Loaded outgoing requests: $outgoingRequests');

      setState(() {
        _userData = Map<String, dynamic>.from(json.decode(response.body));
        _friends = [...friends, ...incomingRequests, ...outgoingRequests];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAcceptRequest(int friendshipId) async {
    try {
      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
      if (token == null) {
        throw Exception('Не авторизован');
      }

      await _friendService.acceptFriendRequest(friendshipId, token);
      await _loadUserData(); // Перезагружаем данные
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _handleDeclineRequest(int friendshipId) async {
    try {
      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
      if (token == null) {
        throw Exception('Не авторизован');
      }

      await _friendService.rejectFriendRequest(friendshipId, token);
      await _loadUserData(); // Перезагружаем данные
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _handleRemoveFriend(int friendshipId) async {
    try {
      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
      if (token == null) {
        throw Exception('Не авторизован');
      }

      // TODO: Реализовать удаление из друзей на бэкенде
      await _loadUserData(); // Перезагружаем данные
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Widget _buildProfileHeader() {
    return Container(
      height: MediaQuery.of(context).size.height / 3,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade700, Colors.blue.shade400],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: _userData?['avatarUrl'] != null
                ? NetworkImage(_userData!['avatarUrl'])
                : const AssetImage('assets/logo.png') as ImageProvider,
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
            _buildInfoRow(Icons.phone, 'Телефон',
                _userData?['phoneNumber'] ?? 'Не указан'),
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
    if (_userPlaces.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Добавленные места',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _userPlaces.length,
                itemBuilder: (context, index) {
                  final place = _userPlaces[index];
                  return Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            place.imageUrl ?? 'https://via.placeholder.com/180',
                            height: 120,
                            width: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          place.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (place.userImages != null &&
                            place.userImages!.isNotEmpty)
                          Text(
                            'Фото: ${place.userImages!.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final acceptedFriends =
        _friends.where((f) => f.status.toLowerCase() == 'accepted').toList();
    final incomingRequests = _friends
        .where((f) => f.status.toLowerCase() == 'pending' && !f.isOutgoing)
        .toList();
    final outgoingRequests = _friends
        .where((f) => f.status.toLowerCase() == 'pending' && f.isOutgoing)
        .toList();

    print('Stats - Accepted friends: ${acceptedFriends.length}');
    print('Stats - Incoming requests: ${incomingRequests.length}');
    print('Stats - Outgoing requests: ${outgoingRequests.length}');

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
                    incomingRequests.isNotEmpty
                        ? 'Друзья (${acceptedFriends.length}) • ${incomingRequests.length}'
                        : 'Друзья (${acceptedFriends.length})',
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('12', 'Встреч'),
                _buildStatItem('${acceptedFriends.length}', 'Друзей'),
                _buildStatItem('${_userPlaces.length}', 'Мест'),
                _buildStatItem('150', 'Очков'),
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
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
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
            friends: _friends,
            onRemoveFriend: _handleRemoveFriend,
            onAcceptRequest: _handleAcceptRequest,
            onDeclineRequest: _handleDeclineRequest,
            onAddFriend: () {
              Navigator.of(context).pushNamed('/friends/search');
            },
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
            ],
          ),
        ),
      ),
    );
  }
}
