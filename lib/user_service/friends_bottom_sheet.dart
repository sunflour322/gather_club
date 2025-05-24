import 'package:flutter/material.dart';
import 'package:gather_club/user_service/friend.dart';
import 'package:gather_club/user_service/friend_service.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class FriendsBottomSheet extends StatefulWidget {
  final List<Friend> friends;
  final Function(int) onRemoveFriend;
  final Function(int) onAcceptRequest;
  final Function(int) onDeclineRequest;
  final VoidCallback onAddFriend;

  const FriendsBottomSheet({
    Key? key,
    required this.friends,
    required this.onRemoveFriend,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    required this.onAddFriend,
  }) : super(key: key);

  @override
  State<FriendsBottomSheet> createState() => _FriendsBottomSheetState();
}

class _FriendsBottomSheetState extends State<FriendsBottomSheet> {
  late final FriendService _friendService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _friendService = FriendService(http.Client());
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
    if (friend.status.toLowerCase() == 'pending' && !friend.isOutgoing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () => widget.onAcceptRequest(friend.friendshipId!),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => widget.onDeclineRequest(friend.friendshipId!),
          ),
        ],
      );
    } else if (friend.status.toLowerCase() == 'accepted') {
      return IconButton(
        icon: const Icon(Icons.person_remove),
        onPressed: () => widget.onRemoveFriend(friend.friendshipId!),
      );
    }
    return const SizedBox.shrink();
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
                TextButton.icon(
                  onPressed: widget.onAddFriend,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Добавить'),
                ),
              ],
            ),
          ),
          const Divider(),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (widget.friends.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'У вас пока нет друзей.\nНажмите "Добавить", чтобы найти друзей.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: widget.friends.length,
                itemBuilder: (context, index) =>
                    _buildFriendTile(widget.friends[index]),
              ),
            ),
        ],
      ),
    );
  }
}
