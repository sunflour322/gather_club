import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../auth_service/auth_provider.dart';
import 'chat_detail_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  late final ChatService _chatService;
  List<Chat> _chats = [];
  List<Chat> _invitedMeetups = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chatService =
        ChatService(Provider.of<AuthProvider>(context, listen: false));
    _loadData();
    _initWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatService.disconnectWebSocket();
    super.dispose();
  }

  Future<void> _initWebSocket() async {
    try {
      await _chatService.connectToWebSocket();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подключения к чату: $e')),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      print('Начинаем загрузку данных...');

      final futures = await Future.wait([
        _chatService.getUserChats(),
        _chatService.getInvitedMeetups(),
      ]);

      if (mounted) {
        final chats = futures[0] as List<Chat>;
        final invitedMeetups = futures[1] as List<Chat>;

        print('Загружено чатов: ${chats.length}');
        print('Активные встречи: ${chats.where((c) => c.isActive).length}');
        print(
            'Завершенные встречи: ${chats.where((c) => c.isCompleted).length}');
        print('Загружено приглашений: ${invitedMeetups.length}');

        // Выводим детали каждой встречи
        for (var chat in chats.where((c) => c.type == ChatType.meetup)) {
          print('Встреча: ${chat.name}');
          print('- ID: ${chat.meetupId}');
          print('- Статус: ${chat.meetupStatus}');
          print('- Статус участника: ${chat.currentUserStatus}');
          print('- Время: ${chat.scheduledTime}');
        }

        setState(() {
          _chats = chats;
          _invitedMeetups = invitedMeetups;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Ошибка при загрузке данных:');
      print(e);
      print(stackTrace);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  List<Chat> _getActiveMeetups() {
    print('Всего чатов: ${_chats.length}');

    for (var chat in _chats) {
      print('Чат: ${chat.name}');
      print('- ID чата: ${chat.chatId}');
      print('- ID встречи: ${chat.meetupId}');
      print('- Тип: ${chat.type}');
      print('- Статус встречи: ${chat.meetupStatus}');
      print('- Статус пользователя: ${chat.currentUserStatus}');
      print('- isActive: ${chat.isActive}');
    }

    // Фильтруем только чаты типа meetup
    final meetupChats = _chats
        .where((chat) => chat.type == ChatType.meetup && chat.meetupId != null)
        .toList();
    print('Чаты типа meetup: ${meetupChats.length}');

    // Фильтруем запланированные встречи
    final plannedMeetups = meetupChats
        .where((chat) => chat.meetupStatus == MeetupStatus.planned)
        .toList();
    print('Запланированные встречи: ${plannedMeetups.length}');

    // Фильтруем принятые встречи
    final acceptedMeetups = plannedMeetups
        .where((chat) => chat.currentUserStatus == ParticipantStatus.accepted)
        .toList();
    print('Принятые встречи: ${acceptedMeetups.length}');

    // Сортируем по времени встречи
    acceptedMeetups.sort((a, b) => (a.scheduledTime ?? DateTime.now())
        .compareTo(b.scheduledTime ?? DateTime.now()));

    for (var chat in acceptedMeetups) {
      print('Активная встреча:');
      print('- ID чата: ${chat.chatId}');
      print('- ID встречи: ${chat.meetupId}');
      print('- Название: ${chat.name}');
      print('- Статус: ${chat.meetupStatus}');
      print('- Статус пользователя: ${chat.currentUserStatus}');
      print('- Время: ${chat.scheduledTime}');
    }

    return acceptedMeetups;
  }

  void _onChatTap(Chat chat) {
    print('Открываем чат:');
    print('- ID: ${chat.chatId}');
    print('- Тип: ${chat.type}');
    print('- MeetupId: ${chat.meetupId}');

    // Для встреч используем meetupId вместо chatId
    final chatId = chat.type == ChatType.meetup ? 16 : chat.chatId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPage(
          chat: chat.copyWith(
              chatId: chatId,
              type: chat.type,
              meetupId: chat.meetupId,
              isGroup: chat.type == ChatType.group),
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _respondToInvitation(Chat chat, bool accept) async {
    try {
      setState(() => _isLoading = true);

      if (accept) {
        await _chatService.acceptMeetupInvitation(chat.meetupId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вы приняли приглашение на встречу'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _chatService.declineMeetupInvitation(chat.meetupId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вы отклонили приглашение на встречу'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Обновляем данные после успешного ответа
      await _loadData();
    } catch (e) {
      print('Ошибка при обработке приглашения:');
      print(e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ошибка при ${accept ? 'принятии' : 'отклонении'} приглашения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildChatList(List<Chat> chats, {bool showActions = false}) {
    print('Building chat list:');
    print('- Number of chats: ${chats.length}');
    for (var chat in chats) {
      print('- Chat: ${chat.name}');
      print('  Type: ${chat.type}');
      print('  Status: ${chat.meetupStatus}');
      print('  User Status: ${chat.currentUserStatus}');
      print('  Is Active: ${chat.isActive}');
    }

    if (chats.isEmpty) {
      return const Center(
        child: Text('Нет доступных чатов'),
      );
    }

    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        return _buildChatTile(chat, showActions: showActions);
      },
    );
  }

  Widget _buildChatTile(Chat chat, {bool showActions = false}) {
    final activeParticipants =
        chat.participants.where((p) => p.leftAt == null).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: chat.createdByAvatar != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Image.network(
                        chat.createdByAvatar!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.group, color: Colors.grey),
                      ),
                    )
                  : const Icon(Icons.group, color: Colors.grey),
            ),
            if (activeParticipants.length > 1)
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
                    '${activeParticipants.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          chat.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chat.scheduledTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Дата встречи: ${_formatDateTime(chat.scheduledTime!)}',
                  style: TextStyle(
                    color: chat.isCompleted ? Colors.grey : Colors.black87,
                  ),
                ),
              ),
            if (chat.lastMessageContent != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  chat.lastMessageContent!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            if (showActions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _respondToInvitation(chat, false),
                      child: const Text('Отклонить'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _respondToInvitation(chat, true),
                      child: const Text('Принять'),
                    ),
                  ],
                ),
              ),
          ],
        ),
        onTap: () => _onChatTap(chat),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Встречи и чаты'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Активные'),
            Tab(text: 'Приглашения'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<Chat>(
              stream: _chatService.chatUpdates,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Ошибка соединения: ${snapshot.error}'),
                  );
                }

                if (snapshot.hasData) {
                  final updatedChat = snapshot.data!;
                  final existingIndex = _chats
                      .indexWhere((chat) => chat.chatId == updatedChat.chatId);

                  if (existingIndex != -1) {
                    setState(() {
                      _chats[existingIndex] = updatedChat;
                    });
                  } else {
                    setState(() {
                      _chats.add(updatedChat);
                    });
                  }
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    Builder(builder: (context) {
                      final activeMeetups = _getActiveMeetups();
                      print('Active meetups tab:');
                      print('- Active meetups count: ${activeMeetups.length}');
                      activeMeetups.forEach((meetup) {
                        print('- Meetup: ${meetup.name}');
                        print('  Is Active: ${meetup.isActive}');
                      });
                      return _buildChatList(activeMeetups);
                    }),
                    _buildChatList(_invitedMeetups, showActions: true),
                  ],
                );
              },
            ),
    );
  }
}
