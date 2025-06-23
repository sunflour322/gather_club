import 'package:flutter/material.dart';
import 'package:gather_club/api_services/user_service/friend.dart';
import 'package:gather_club/api_services/user_service/friend_service.dart';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
import 'package:gather_club/widgets/custom_notification.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class InviteFriendsPage extends StatefulWidget {
  final List<Friend>? initialSelectedFriends;

  const InviteFriendsPage({Key? key, this.initialSelectedFriends})
      : super(key: key);

  @override
  State<InviteFriendsPage> createState() => _InviteFriendsPageState();
}

class _InviteFriendsPageState extends State<InviteFriendsPage> {
  late FriendService _friendService;
  List<Friend> _friends = [];
  Set<int> _selectedFriendIds = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _friendService = FriendService(http.Client());

    // Инициализируем выбранных друзей, если они предоставлены
    if (widget.initialSelectedFriends != null &&
        widget.initialSelectedFriends!.isNotEmpty) {
      _selectedFriendIds =
          widget.initialSelectedFriends!.map((friend) => friend.userId).toSet();
    }

    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }
      final friends = await _friendService.getAllFriends(token);
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка при загрузке списка друзей: $e',
        );
      }
    }
  }

  void _toggleFriendSelection(int friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  void _confirmSelection() {
    final selectedFriends = _friends
        .where((friend) => _selectedFriendIds.contains(friend.userId))
        .toList();
    Navigator.pop(context, selectedFriends);
  }

  List<Friend> get _filteredFriends {
    if (_searchQuery.isEmpty) return _friends;
    return _friends.where((friend) {
      return friend.username.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // Получаем статус друга из списка initialSelectedFriends
  String? _getFriendStatus(int userId) {
    if (widget.initialSelectedFriends == null) return null;

    final friend = widget.initialSelectedFriends!.firstWhere(
      (f) => f.userId == userId,
      orElse: () => Friend(
          userId: -1, username: '', status: 'unknown', isOutgoing: false),
    );

    return friend.userId != -1 ? friend.status : null;
  }

  // Проверяем, можно ли выбрать друга
  bool _canSelectFriend(int userId) {
    if (widget.initialSelectedFriends == null) return true;

    // Находим друга в списке приглашенных, если он там есть
    final existingFriend = widget.initialSelectedFriends!.firstWhere(
      (f) => f.userId == userId,
      orElse: () => Friend(
          userId: -1, username: '', status: 'unknown', isOutgoing: false),
    );

    // Если друга нет в списке, его можно выбрать
    if (existingFriend.userId == -1) return true;

    // Если друг уже принял или отклонил приглашение, его нельзя выбрать
    if (existingFriend.status.toLowerCase() == 'accepted' ||
        existingFriend.status.toLowerCase() == 'declined') {
      return false;
    }

    // Если друг имеет статус "invited" (ожидает), его можно выбрать повторно
    // чтобы убрать из списка приглашенных
    return existingFriend.status.toLowerCase() == 'invited';
  }

  Widget _buildFriendItem(Friend friend) {
    final isSelected = _selectedFriendIds.contains(friend.userId);
    final status = _getFriendStatus(friend.userId);
    final canSelect = _canSelectFriend(friend.userId);

    // Определяем цвет и текст статуса
    Color statusColor = AppTheme.accentColor;
    String? statusText;

    if (status != null) {
      switch (status.toLowerCase()) {
        case 'accepted':
          statusColor = Colors.green;
          statusText = 'Принято';
          break;
        case 'invited':
          statusColor = Colors.orange;
          statusText = 'Ожидает';
          break;
        case 'declined':
          statusColor = Colors.red;
          statusText = 'Отклонено';
          break;
      }
    }

    return GestureDetector(
      onTap: canSelect ? () => _toggleFriendSelection(friend.userId) : null,
      child: Opacity(
        opacity: canSelect ? 1.0 : 0.5,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: status != null
                          ? statusColor
                          : (isSelected
                              ? AppTheme.accentColor
                              : Colors.grey[300]!),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: friend.avatarUrl != null
                        ? Image.network(
                            friend.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/default_avatar.png',
                                fit: BoxFit.cover,
                              );
                            },
                          )
                        : Image.asset(
                            'assets/default_avatar.png',
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                if (status != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              friend.username,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (statusText != null)
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пригласить друзей'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск друзей',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
        actions: [
          TextButton(
            // Кнопка активна, если есть выбранные друзья или если изначально были выбраны друзья
            // (это позволяет подтвердить удаление всех приглашенных)
            onPressed: (_selectedFriendIds.isNotEmpty ||
                    (widget.initialSelectedFriends != null &&
                        widget.initialSelectedFriends!.isNotEmpty))
                ? _confirmSelection
                : null,
            child: Text(
              'Готово (${_selectedFriendIds.length})',
              style: TextStyle(
                color: (_selectedFriendIds.isNotEmpty ||
                        (widget.initialSelectedFriends != null &&
                            widget.initialSelectedFriends!.isNotEmpty))
                    ? AppTheme.accentColor
                    : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? const Center(
                  child: Text('У вас пока нет друзей'),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _filteredFriends.length,
                  itemBuilder: (context, index) {
                    return _buildFriendItem(_filteredFriends[index]);
                  },
                ),
    );
  }
}
