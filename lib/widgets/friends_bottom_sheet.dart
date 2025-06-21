import 'package:flutter/material.dart';
import 'package:gather_club/api_services/user_service/friend.dart';
import 'package:gather_club/api_services/user_service/friend_service.dart';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:gather_club/widgets/custom_notification.dart';

class FriendsBottomSheet extends StatefulWidget {
  final List<Friend> friends;
  final Function(int) onRemoveFriend;
  final Function(int) onAcceptRequest;
  final Function(int) onDeclineRequest;
  final VoidCallback onAddFriend;
  final VoidCallback? onFriendsUpdated;

  const FriendsBottomSheet({
    Key? key,
    required this.friends,
    required this.onRemoveFriend,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    required this.onAddFriend,
    this.onFriendsUpdated,
  }) : super(key: key);

  @override
  State<FriendsBottomSheet> createState() => _FriendsBottomSheetState();
}

class _FriendsBottomSheetState extends State<FriendsBottomSheet> {
  late final FriendService _friendService;
  bool _isLoading = false;
  List<Friend> _friends = [];
  Map<int, bool> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _friendService = FriendService(http.Client());
    _friends = widget.friends;
  }

  Future<void> _refreshFriends() async {
    try {
      setState(() => _isLoading = true);

      final token =
          await Provider.of<AuthProvider>(context, listen: false).getToken();
      if (token == null) throw Exception('Не авторизован');

      final friends = await _friendService.getAllFriends(token);
      final incomingRequests = await _friendService.getIncomingRequests(token);
      final outgoingRequests = await _friendService.getOutgoingRequests(token);

      if (mounted) {
        setState(() {
          _friends = [...friends, ...incomingRequests, ...outgoingRequests];
          _isLoading = false;
        });
      }

      widget.onFriendsUpdated?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
          context,
          'Ошибка: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _handleAcceptRequest(Friend friend) async {
    if (_processingIds[friend.friendshipId!] == true) return;

    try {
      setState(() => _processingIds[friend.friendshipId!] = true);

      await widget.onAcceptRequest(friend.friendshipId!);

      if (mounted) {
        setState(() {
          _friends = _friends.map((f) {
            if (f.friendshipId == friend.friendshipId) {
              return Friend(
                userId: f.userId,
                username: f.username,
                avatarUrl: f.avatarUrl,
                status: 'accepted',
                isOutgoing: f.isOutgoing,
                friendshipId: f.friendshipId,
              );
            }
            return f;
          }).toList();
          _processingIds[friend.friendshipId!] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds[friend.friendshipId!] = false);
        CustomNotification.show(
          context,
          e.toString(),
        );
      }
    }
  }

  Future<void> _handleDeclineRequest(Friend friend) async {
    if (_processingIds[friend.friendshipId!] == true) return;

    try {
      setState(() => _processingIds[friend.friendshipId!] = true);

      await widget.onDeclineRequest(friend.friendshipId!);

      if (mounted) {
        setState(() {
          _friends.removeWhere((f) => f.friendshipId == friend.friendshipId);
          _processingIds[friend.friendshipId!] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds[friend.friendshipId!] = false);
        CustomNotification.show(
          context,
          e.toString(),
        );
      }
    }
  }

  Future<void> _handleRemoveFriend(Friend friend) async {
    if (_processingIds[friend.friendshipId!] == true) return;

    try {
      setState(() => _processingIds[friend.friendshipId!] = true);

      await widget.onRemoveFriend(friend.friendshipId!);

      if (mounted) {
        setState(() {
          _friends.removeWhere((f) => f.friendshipId == friend.friendshipId);
          _processingIds[friend.friendshipId!] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds[friend.friendshipId!] = false);
        CustomNotification.show(
          context,
          e.toString(),
        );
      }
    }
  }

  Widget _buildFriendTile(Friend friend) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: friend.avatarUrl != null
            ? NetworkImage(friend.avatarUrl!)
            : const AssetImage('assets/default_avatar.png') as ImageProvider,
      ),
      title: Text(friend.username),
      subtitle: Text(_getFriendshipStatus(friend)),
      trailing: _buildActionButtons(friend),
    );
  }

  String _getFriendshipStatus(Friend friend) {
    switch (friend.status.toLowerCase()) {
      case 'pending':
        return friend.isOutgoing ? 'Запрос отправлен' : 'Входящий запрос';
      case 'accepted':
        return 'В друзьях';
      case 'rejected':
        return 'Отклонено';
      default:
        return 'Неизвестный статус';
    }
  }

  Widget _buildActionButtons(Friend friend) {
    final bool isProcessing = _processingIds[friend.friendshipId!] == true;

    if (friend.status.toLowerCase() == 'pending' && !friend.isOutgoing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check, color: Colors.green),
            onPressed: isProcessing ? null : () => _handleAcceptRequest(friend),
          ),
          IconButton(
            icon: isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.close, color: Colors.red),
            onPressed:
                isProcessing ? null : () => _handleDeclineRequest(friend),
          ),
        ],
      );
    } else if (friend.status.toLowerCase() == 'accepted') {
      return IconButton(
        icon: isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.person_remove),
        onPressed: isProcessing ? null : () => _handleRemoveFriend(friend),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFriendsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final acceptedFriends =
        _friends.where((f) => f.status.toLowerCase() == 'accepted').toList();
    final incomingRequests = _friends
        .where((f) => f.status.toLowerCase() == 'pending' && !f.isOutgoing)
        .toList();
    final outgoingRequests = _friends
        .where((f) => f.status.toLowerCase() == 'pending' && f.isOutgoing)
        .toList();

    if (_friends.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            'У вас пока нет друзей.\nНажмите "Добавить", чтобы найти друзей.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _refreshFriends,
        child: ListView(
          children: [
            if (incomingRequests.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Входящие запросы',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...incomingRequests.map((friend) => _buildFriendTile(friend)),
              const Divider(),
            ],
            if (acceptedFriends.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Друзья',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...acceptedFriends.map((friend) => _buildFriendTile(friend)),
            ],
            if (outgoingRequests.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Исходящие запросы',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...outgoingRequests.map((friend) => _buildFriendTile(friend)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Друзья',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshFriends,
                    ),
                    TextButton.icon(
                      onPressed: widget.onAddFriend,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Добавить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          _buildFriendsList(),
        ],
      ),
    );
  }
}
