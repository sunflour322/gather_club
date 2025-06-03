import 'package:flutter/material.dart';
import 'package:gather_club/user_service/friend.dart';
import 'package:gather_club/user_service/friend_service.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:gather_club/widgets/custom_notification.dart';

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({Key? key}) : super(key: key);

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService(http.Client());
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Friend> _friends = [];
  List<Friend> _pendingRequests = [];
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
      if (token == null) {
        throw Exception('Не авторизован');
      }

      // Получаем ID текущего пользователя
      _currentUserId = await _friendService.getCurrentUserId(token);
      print('Current user ID: $_currentUserId');

      // Загружаем списки друзей и запросов параллельно
      final results = await Future.wait([
        _friendService.getAllUsers(token),
        _friendService.getAllFriends(token),
        _friendService.getIncomingRequests(token),
        _friendService.getOutgoingRequests(token),
      ]);

      if (mounted) {
        setState(() {
          _allUsers = results[0] as List<Map<String, dynamic>>;
          _friends = results[1] as List<Friend>;
          _pendingRequests = [
            ...(results[2] as List<Friend>),
            ...(results[3] as List<Friend>)
          ];
          _isLoading = false;
        });

        // Применяем текущий поисковый запрос к загруженным пользователям
        if (_searchController.text.isNotEmpty) {
          _filterUsers(_searchController.text);
        }
      }
    } catch (e) {
      print('Error loading initial data: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool _shouldShowUser(Map<String, dynamic> user) {
    final userId = user['userId'];

    print('Checking user $userId (${user['username']})');

    // Не показываем текущего пользователя
    if (userId == _currentUserId) {
      print('Skipping current user');
      return false;
    }

    // Не показываем существующих друзей
    if (_friends.any((friend) => friend.userId == userId)) {
      print('Skipping friend');
      return false;
    }

    // Не показываем пользователей с активными запросами
    if (_pendingRequests.any((request) => request.userId == userId)) {
      print('Skipping user with pending request');
      return false;
    }

    print('User $userId will be shown in search results');
    return true;
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _searchResults = _allUsers.where((user) {
        if (!_shouldShowUser(user)) {
          return false;
        }

        final username = (user['username'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        return username.contains(lowercaseQuery) ||
            email.contains(lowercaseQuery);
      }).toList();
    });
  }

  Future<void> _sendFriendRequest(int userId) async {
    try {
      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
      if (token == null) {
        throw Exception('Не авторизован');
      }

      setState(() => _isLoading = true);
      await _friendService.sendFriendRequest(userId, token);

      // Обновляем списки после отправки запроса
      final incomingRequests = await _friendService.getIncomingRequests(token);
      final outgoingRequests = await _friendService.getOutgoingRequests(token);

      if (mounted) {
        setState(() {
          _pendingRequests = [...incomingRequests, ...outgoingRequests];
          _isLoading = false;
        });

        // Обновляем результаты поиска
        _filterUsers(_searchController.text);

        CustomNotification.show(
          context,
          'Запрос в друзья отправлен',
        );
      }
    } catch (e) {
      print('Error sending friend request: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка при отправке запроса: ${e.toString()}',
        );
      }
    }
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return const Center(
        child: Text(
          'Начните вводить имя пользователя для поиска',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'Пользователи не найдены',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user['avatarUrl'] != null
                ? NetworkImage(user['avatarUrl'])
                : const AssetImage('assets/logo.png') as ImageProvider,
          ),
          title: Text(user['username'] ?? ''),
          subtitle: Text(user['email'] ?? ''),
          trailing: TextButton(
            onPressed: () => _sendFriendRequest(user['userId']),
            child: const Text('Добавить в друзья'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentColor,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск друзей'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Введите имя пользователя или email',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterUsers('');
                          },
                        )
                      : null,
                ),
                onChanged: _filterUsers,
              ),
            ),
            Expanded(
              child: _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
