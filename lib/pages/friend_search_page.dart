import 'package:flutter/material.dart';
import 'package:gather_club/user_service/friend.dart';
import 'package:gather_club/user_service/friend_service.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);

      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
      if (token == null) {
        throw Exception('Не авторизован');
      }

      final users = await _friendService.getAllUsers(token);
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });

      // Применяем текущий поисковый запрос к загруженным пользователям
      if (_searchController.text.isNotEmpty) {
        _filterUsers(_searchController.text);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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

      print(
          'Отправка запроса в друзья. UserId: $userId, Token: ${token.substring(0, 10)}...');
      await _friendService.sendFriendRequest(userId, token);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запрос в друзья отправлен')),
      );
      // Обновляем список пользователей
      _loadUsers();
    } catch (e) {
      print('Ошибка при отправке запроса в друзья: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
      ),
      body: Column(
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
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
