import 'package:flutter/material.dart';
import 'package:gather_club/services/user_location_service.dart';

class FriendInfoOverlay extends StatelessWidget {
  final UserLocation friendLocation;
  final VoidCallback? onRouteBuilt;
  final VoidCallback? onRouteCleared;
  final VoidCallback? onChat;
  final VoidCallback onClose;

  const FriendInfoOverlay({
    super.key,
    required this.friendLocation,
    this.onRouteBuilt,
    this.onRouteCleared,
    this.onChat,
    required this.onClose,
  });

  String _formatTimestamp(DateTime timestamp) {
    // Корректируем timestamp на 3 часа (предполагаем, что это разница между UTC и местным временем)
    final adjustedTimestamp = timestamp.add(const Duration(hours: 3));
    final now = DateTime.now();
    final difference = now.difference(adjustedTimestamp);

    print('Форматирование времени в friend_info_overlay.dart:');
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

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      right: 10,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: friendLocation.userAvatar != null
                        ? NetworkImage(friendLocation.userAvatar!)
                        : null,
                    child: friendLocation.userAvatar == null
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friendLocation.userName ?? 'Друг',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRouteBuilt,
                  icon: const Icon(Icons.directions_walk, size: 24),
                  label: const Text(
                    'Маршрут',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.1),
                    foregroundColor: Colors.green,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.green.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
