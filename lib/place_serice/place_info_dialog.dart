import 'package:flutter/material.dart';
import 'package:gather_club/place_serice/place.dart';

class PlaceInfoDialog extends StatelessWidget {
  final Place place;

  const PlaceInfoDialog({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(place.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (place.description != null) Text(place.description!),
          const SizedBox(height: 10),
          if (place.imageUrl != null)
            Image.network(
              place.imageUrl!,
              height: 50,
              width: 50,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
