import 'package:flutter/material.dart';
import '../models/chat_participant_info.dart';
import 'package:intl/intl.dart';

class ParticipantsDialog extends StatelessWidget {
  final List<ChatParticipantInfo> participants;

  const ParticipantsDialog({
    super.key,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Участники встречи',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final participant = participants[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundImage: participant.avatarUrl != null
                                ? NetworkImage(participant.avatarUrl!)
                                : null,
                            child: participant.avatarUrl == null
                                ? Text(participant.username[0].toUpperCase())
                                : null,
                          ),
                          if (participant.isOnline == true)
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
                      title: Row(
                        children: [
                          Text(
                            participant.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (participant.isOnline == true)
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Роль: ${_translateRole(participant.role)}',
                            style: TextStyle(
                              color: participant.role.toLowerCase() == 'admin'
                                  ? Colors.blue
                                  : Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Присоединился: ${DateFormat('dd.MM.yyyy HH:mm').format(participant.joinedAt)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _translateRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Организатор';
      case 'member':
        return 'Участник';
      case 'moderator':
        return 'Модератор';
      case 'guest':
        return 'Гость';
      default:
        return role;
    }
  }
}
