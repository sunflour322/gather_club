import 'package:flutter/material.dart';
import 'package:gather_club/place_serice/place.dart';

class PlaceInfoDialog extends StatelessWidget {
  final Place place;
  final bool isLoading;

  const PlaceInfoDialog({
    super.key,
    required this.place,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.all(16),
          child: isLoading ? _buildShimmer() : _buildContent(),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Images placeholder with like/dislike buttons
        Stack(
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Rest of the shimmer content...
        // ... (остальной код _buildShimmer остается без изменений)
      ],
    );
  }

  Widget _buildContent() {
    final userImages = place.userImages ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Карусель фотографий с кнопками лайка/дизлайка
        Stack(
          children: [
            // Карусель фотографий
            SizedBox(
              height: 250,
              child: userImages.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                        child: Icon(Icons.photo_library,
                            size: 50, color: Colors.grey),
                      ),
                    )
                  : PageView.builder(
                      itemCount: userImages.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            userImages[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        );
                      },
                    ),
            ),
            // Кнопки лайка/дизлайка
            if (userImages.isNotEmpty)
              Positioned(
                right: 10,
                top: 10,
                child: Column(
                  children: [
                    // Кнопка лайка
                    FloatingActionButton(
                      heroTag: 'like_btn',
                      onPressed: () {
                        // Обработка лайка
                      },
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.thumb_up, color: Colors.green),
                    ),
                    const SizedBox(height: 16),
                    // Кнопка дизлайка
                    FloatingActionButton(
                      heroTag: 'dislike_btn',
                      onPressed: () {
                        // Обработка дизлайка
                      },
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.thumb_down, color: Colors.red),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Название и категория
        Row(
          children: [
            Expanded(
              child: Text(
                place.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                place.category ?? 'Категория',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Описание
        if (place.description != null)
          Text(
            place.description!,
            style: const TextStyle(fontSize: 16),
          ),
        const SizedBox(height: 16),

        // Время работы и телефон
        Row(
          children: [
            const Icon(Icons.access_time, size: 16),
            const SizedBox(width: 8),
            Text(
              place.workingHours ?? '9:00 - 22:00',
              style: const TextStyle(fontSize: 14),
            ),
            const Spacer(),
            const Icon(Icons.phone, size: 16),
            const SizedBox(width: 8),
            Text(
              place.phone ?? '+7 (XXX) XXX-XX-XX',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const Spacer(),

        // Кнопки действий (стилизованные)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Кнопка маршрута
            _buildActionButton(
              icon: Icons.directions,
              label: 'Маршрут',
              onPressed: () {
                // Прокладывание маршрута
              },
            ),

            // Кнопка добавления фото
            _buildActionButton(
              icon: Icons.add_a_photo,
              label: 'Добавить фото',
              onPressed: () {
                // Добавление фото
              },
            ),

            // Кнопка получения валюты
            _buildActionButton(
              icon: Icons.monetization_on,
              label: 'Получить монеты',
              onPressed: () {
                // Получение валюты
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
