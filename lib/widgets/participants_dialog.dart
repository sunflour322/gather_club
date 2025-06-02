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
                      leading: CircleAvatar(
                        backgroundImage: participant.avatarUrl != null
                            ? NetworkImage(participant.avatarUrl!)
                            : null,
                        child: participant.avatarUrl == null
                            ? Text(participant.username[0].toUpperCase())
                            : null,
                      ),
                      title: Text(
                        participant.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
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
      case 'participant':
        return 'Участник';
      case 'moderator':
        return 'Модератор';
      default:
        return role;
    }
  }
}
