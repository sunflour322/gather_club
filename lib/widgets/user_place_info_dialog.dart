import 'package:flutter/material.dart';
import '../place_serice/user_custom_place.dart';

class UserPlaceInfoDialog extends StatelessWidget {
  final UserCustomPlace place;
  final Function(UserCustomPlace) onRouteBuilt;
  final VoidCallback onRouteCleared;
  final VoidCallback onDelete;

  const UserPlaceInfoDialog({
    Key? key,
    required this.place,
    required this.onRouteBuilt,
    required this.onRouteCleared,
    required this.onDelete,
  }) : super(key: key);

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
          // Полоска для перетаскивания
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

          // Основной контент
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Название и дата создания
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (place.createdAt != null)
                      Text(
                        place.createdAt!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Описание
                if (place.description != null && place.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      place.description!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                // Координаты
                Text(
                  'Координаты: ${place.latitude.toStringAsFixed(6)}, ${place.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Кнопки действий
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => onRouteBuilt(place),
                        icon: const Icon(Icons.directions_walk, size: 20),
                        label: const Text('Маршрут'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Удалить метку?'),
                            content:
                                const Text('Это действие нельзя отменить.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Отмена'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // Закрываем диалог
                                  Navigator.pop(context); // Закрываем инфо
                                  onDelete();
                                },
                                child: const Text(
                                  'Удалить',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
