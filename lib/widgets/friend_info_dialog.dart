import 'package:flutter/material.dart';
import 'package:gather_club/api_services/user_location_service.dart';

class FriendInfoDialog extends StatelessWidget {
  final UserLocation friendLocation;
  final VoidCallback? onRouteBuilt;
  final VoidCallback? onRouteCleared;
  final VoidCallback? onChat;

  const FriendInfoDialog({
    super.key,
    required this.friendLocation,
    this.onRouteBuilt,
    this.onRouteCleared,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Аватар и имя
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: friendLocation.userAvatar != null
                          ? NetworkImage(friendLocation.userAvatar!)
                          : null,
                      child: friendLocation.userAvatar == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    if (friendLocation.isOnline == true)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            friendLocation.userName ?? 'Друг',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (friendLocation.isOnline == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'онлайн',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        'Был в сети: ${_formatTimestamp(friendLocation.timestamp)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Кнопки действий
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.directions_walk,
                  label: 'Маршрут',
                  color: Colors.green,
                  onPressed: onRouteBuilt,
                ),
                _buildActionButton(
                  icon: Icons.chat,
                  label: 'Чат',
                  color: Colors.blue,
                  onPressed: onChat,
                ),
                _buildActionButton(
                  icon: Icons.close,
                  label: 'Закрыть',
                  color: Colors.red,
                  onPressed: () {
                    onRouteCleared?.call();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: Icon(icon, color: color, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    // Корректируем timestamp на 3 часа (предполагаем, что это разница между UTC и местным временем)
    final adjustedTimestamp = timestamp.add(const Duration(hours: 3));
    final now = DateTime.now();
    final difference = now.difference(adjustedTimestamp);

    print('Форматирование времени в friend_info_dialog.dart:');
    print('Текущее время: $now');
    print('Исходный timestamp: $timestamp');
    print('Скорректированный timestamp: $adjustedTimestamp');
    print('Разница в минутах: ${difference.inMinutes}');
    print('Разница в часах: ${difference.inHours}');

    if (difference.inMinutes < 1) {
      return 'только что';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ч назад';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн назад';
    } else {
      return '${adjustedTimestamp.day}.${adjustedTimestamp.month}.${adjustedTimestamp.year}';
    }
  }
}
