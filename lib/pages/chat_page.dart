import 'package:flutter/material.dart';
import 'chat_detail_page.dart';

class Chat {
  final String id;
  final String name;
  final String lastMessage;
  final DateTime lastMessageTime;
  final List<ChatParticipant> participants;
  final String? imageUrl;

  Chat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.participants,
    this.imageUrl,
  });
}

class ChatParticipant {
  final String id;
  final String name;
  final String? avatarUrl;

  ChatParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
  });
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Временные данные для демонстрации
  final List<Chat> _chats = [
    Chat(
      id: '1',
      name: 'Встреча в парке',
      lastMessage: 'До встречи осталось 2 часа!',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 30)),
      participants: [
        ChatParticipant(id: '1', name: 'Анна', avatarUrl: 'assets/logo.png'),
        ChatParticipant(id: '2', name: 'Иван', avatarUrl: 'assets/logo.png'),
        ChatParticipant(id: '3', name: 'Мария', avatarUrl: 'assets/logo.png'),
      ],
    ),
    Chat(
      id: '2',
      name: 'Кофе в центре',
      lastMessage: 'Принесу печенье!',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      participants: [
        ChatParticipant(id: '4', name: 'Петр', avatarUrl: 'assets/logo.png'),
        ChatParticipant(id: '5', name: 'Елена', avatarUrl: 'assets/logo.png'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return Dismissible(
            key: Key(chat.id),
            direction: DismissDirection.horizontal,
            background: Container(
              color: Colors.grey[200],
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Icon(Icons.arrow_back_ios, color: Colors.grey),
            ),
            secondaryBackground: Container(
              color: Colors.grey[200],
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: chat.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Image.asset(
                                chat.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.group, color: Colors.grey),
                    ),
                    if (chat.participants.length > 1)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${chat.participants.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(chat.lastMessageTime),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      chat.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 30,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: chat.participants.length,
                        itemBuilder: (context, index) {
                          final participant = chat.participants[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: participant.avatarUrl != null
                                  ? AssetImage(participant.avatarUrl!)
                                  : null,
                              child: participant.avatarUrl == null
                                  ? Text(
                                      participant.name[0],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailPage(chat: chat),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}д';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}ч';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}м';
    } else {
      return 'только что';
    }
  }
}
