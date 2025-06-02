import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../auth_service/auth_provider.dart';
import 'chat_detail_page.dart';
import '../models/chat_participant_info.dart';

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
  List<Chat> _archivedMeetups = [];
  bool _isLoading = true;
  late TabController _tabController;
  final Map<int, List<ChatParticipantInfo>> _chatParticipants = {};

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

      // Загружаем активные встречи
      final activeMeetups = await _chatService.getUserChats();
      print('Загружено активных встреч: ${activeMeetups.length}');

      // Загружаем информацию о чатах для каждой активной встречи
      final List<Chat> chatsWithMessages = [];
      for (var meetup in activeMeetups) {
        try {
          // Пытаемся получить информацию о чате для встречи
          final chat = await _chatService.getChatByMeetupId(meetup.meetupId!);
          chatsWithMessages.add(chat);

          // Загружаем информацию об участниках
          final participants =
              await _chatService.getChatParticipantsInfo(chat.chatId);
          _chatParticipants[chat.chatId] = participants;
          print(
              'Загружено участников для встречи ${chat.chatId}: ${participants.length}');
        } catch (e) {
          // Если не удалось получить чат, используем данные встречи
          print('Не удалось получить чат для встречи ${meetup.meetupId}: $e');
          chatsWithMessages.add(meetup);

          // Загружаем информацию об участниках для встречи
          try {
            final participants =
                await _chatService.getChatParticipantsInfo(meetup.chatId);
            _chatParticipants[meetup.chatId] = participants;
          } catch (e) {
            print(
                'Ошибка при загрузке участников встречи ${meetup.chatId}: $e');
            _chatParticipants[meetup.chatId] = [];
          }
        }
      }

      // Загружаем приглашения
      List<Chat> invitedMeetups = [];
      try {
        invitedMeetups = await _chatService.getInvitedMeetups();
        print('Загружено приглашений: ${invitedMeetups.length}');

        // Обрабатываем приглашения
        for (int i = 0; i < invitedMeetups.length; i++) {
          var chat = invitedMeetups[i];
          print('Приглашение $i до обработки:');
          print('- ID: ${chat.chatId}');
          print('- Название: ${chat.name}');
          print('- Время: ${chat.scheduledTime}');
          print('- Организатор: ${chat.createdByName}');
          print('- Участники: ${chat.participants.length}');
          print('- lastMessageContent: ${chat.lastMessageContent}');

          // Принудительно устанавливаем lastMessageContent в null для приглашений
          invitedMeetups[i] = chat.copyWith(lastMessageContent: null);
        }

        // Загружаем информацию об участниках для приглашений
        for (var chat in invitedMeetups) {
          try {
            final participants =
                await _chatService.getChatParticipantsInfo(chat.chatId);
            _chatParticipants[chat.chatId] = participants;
            print(
                'Загружено участников для приглашения ${chat.chatId}: ${participants.length}');
          } catch (e) {
            print(
                'Ошибка при загрузке участников приглашения ${chat.chatId}: $e');
            // Если не удалось загрузить участников, создаем пустой список
            _chatParticipants[chat.chatId] = [];
          }
        }
      } catch (e) {
        print('Ошибка при получении приглашений:');
        print(e);
      }

      if (mounted) {
        setState(() {
          _chats = chatsWithMessages;
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

  Future<void> _loadArchivedMeetups() async {
    setState(() => _isLoading = true);
    try {
      print('Начинаем загрузку архивных встреч...');

      // Загружаем архивные встречи
      final archivedMeetups = await _chatService.getArchivedMeetups();
      print('Загружено архивных встреч: ${archivedMeetups.length}');

      // Для архивных встреч участники уже должны быть в объекте chat
      for (var chat in archivedMeetups) {
        // Создаем список для хранения всех участников
        final List<ChatParticipantInfo> allParticipants = [];

        // Флаг для отслеживания, добавлен ли организатор
        bool creatorIncluded = false;

        // Преобразуем ChatParticipant в ChatParticipantInfo
        if (chat.participants.isNotEmpty) {
          for (var p in chat.participants) {
            final participantInfo = ChatParticipantInfo(
              userId: p.userId,
              username: p.name,
              avatarUrl: p.avatarUrl,
              // Определяем роль: если это создатель, то "admin", иначе "participant"
              role: p.userId == chat.createdById ? 'admin' : 'participant',
              joinedAt: p.joinedAt,
            );

            allParticipants.add(participantInfo);

            // Проверяем, является ли этот участник организатором
            if (p.userId == chat.createdById) {
              creatorIncluded = true;
            }
          }

          // Если организатор не включен в список участников, добавляем его
          if (!creatorIncluded) {
            print(
                'Добавляем организатора в список участников для архивной встречи ${chat.chatId}');
            allParticipants.add(
              ChatParticipantInfo(
                userId: chat.createdById,
                username: chat.createdByName,
                avatarUrl: chat.createdByAvatar,
                role: 'admin',
                joinedAt: chat.createdAt,
              ),
            );
          }

          _chatParticipants[chat.chatId] = allParticipants;
          print(
              'Преобразовано ${allParticipants.length} участников для архивной встречи ${chat.chatId}:');
          for (var i = 0; i < allParticipants.length; i++) {
            print(
                '- Участник #$i: ${allParticipants[i].username} (ID: ${allParticipants[i].userId}, роль: ${allParticipants[i].role})');
          }
        } else {
          // Если по какой-то причине участников нет, добавляем хотя бы организатора
          print(
              'Нет участников для архивной встречи ${chat.chatId}, добавляем организатора');
          _chatParticipants[chat.chatId] = [
            ChatParticipantInfo(
              userId: chat.createdById,
              username: chat.createdByName,
              avatarUrl: chat.createdByAvatar,
              role: 'admin',
              joinedAt: chat.createdAt,
            )
          ];
        }
      }

      if (mounted) {
        setState(() {
          _archivedMeetups = archivedMeetups;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Ошибка при загрузке архивных встреч:');
      print(e);
      print(stackTrace);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки архивных встреч: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String timeStr =
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (date == today) {
      return 'Сегодня в $timeStr';
    } else if (date == tomorrow) {
      return 'Завтра в $timeStr';
    } else {
      return '${dateTime.day}.${dateTime.month}.${dateTime.year} в $timeStr';
    }
  }

  void _onChatTap(Chat chat, {bool isArchived = false}) {
    print('Открываем чат:');
    print('- ID: ${chat.chatId}');
    print('- Тип: ${chat.type}');
    print('- MeetupId: ${chat.meetupId}');
    print('- Архивный: $isArchived');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPage(
          chat: chat.copyWith(
              type: chat.type,
              meetupId: chat.meetupId,
              isGroup: chat.type == ChatType.group),
          isArchived: isArchived,
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
    // Больше не нужно фильтровать по статусу completed, так как API возвращает только активные встречи
    List<Chat> filteredChats = chats;

    if (filteredChats.isEmpty) {
      return Center(
        child: Text(
          showActions ? 'Нет новых приглашений' : 'Нет активных встреч',
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    print(
        'Building chat list. showActions: $showActions, chats count: ${filteredChats.length}');

    // Если это список приглашений, убедимся, что lastMessageContent = null
    List<Chat> processedChats = filteredChats;
    if (showActions) {
      processedChats = filteredChats
          .map((chat) => chat.copyWith(lastMessageContent: null))
          .toList();
    }

    return ListView.builder(
      itemCount: processedChats.length,
      itemBuilder: (context, index) {
        final chat = processedChats[index];
        if (showActions) {
          print('Приглашение #$index:');
          print('- ID: ${chat.chatId}');
          print('- Название: ${chat.name}');
          print('- Время: ${chat.scheduledTime}');
          print('- Последнее сообщение: ${chat.lastMessageContent}');
        }
        return _buildChatTile(chat,
            showActions: showActions, isArchived: false);
      },
    );
  }

  Widget _buildChatTile(Chat chat,
      {bool showActions = false, bool isArchived = false}) {
    final participants = _chatParticipants[chat.chatId] ?? [];

    // Формируем текст участников: всегда показываем создателя и других участников
    String participantsText;
    if (participants.isEmpty) {
      // Если список участников пуст, показываем только создателя
      participantsText = chat.createdByName;
    } else {
      // Создаем полный список участников, включая организатора
      final allParticipants = <String>[];

      // Добавляем организатора с отметкой (организатор)
      bool creatorIncluded = false;

      // Проверяем, есть ли организатор среди участников
      for (var p in participants) {
        if (p.userId == chat.createdById) {
          allParticipants.add('${p.username} (организатор)');
          creatorIncluded = true;
        } else {
          allParticipants.add(p.username);
        }
      }

      // Если организатора нет в списке участников, добавляем его
      if (!creatorIncluded) {
        allParticipants.insert(0, '${chat.createdByName} (организатор)');
      }

      participantsText = allParticipants.join(', ');
    }

    print('Formatting date for chat ${chat.chatId}:');
    print('scheduledTime: ${chat.scheduledTime}');
    print('lastMessageContent: ${chat.lastMessageContent}');
    print('showActions: $showActions');
    print('isArchived: $isArchived');
    print('participants: $participantsText');

    final formattedDate = chat.scheduledTime != null
        ? _formatDateTime(chat.scheduledTime!)
        : 'Время не указано';

    print('Formatted date: $formattedDate');

    // Для приглашений и архивных встреч не показываем последнее сообщение
    final shouldShowLastMessage =
        !showActions && !isArchived && chat.lastMessageContent != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: chat.createdByAvatar != null
                  ? NetworkImage(chat.createdByAvatar!)
                  : null,
              child: chat.createdByAvatar == null
                  ? Text(chat.createdByName[0].toUpperCase())
                  : null,
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
                const SizedBox(height: 4),
                Text(
                  chat.createdByName,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    const Text(
                      'Участники: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      participantsText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
            trailing: showActions
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _respondToInvitation(chat, true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _respondToInvitation(chat, false),
                      ),
                    ],
                  )
                : null,
            onTap: showActions
                ? null
                : () => _onChatTap(chat, isArchived: isArchived),
          ),
          // Показываем блок с последним сообщением только для активных встреч
          if (shouldShowLastMessage)
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 12,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chat.lastMessageContent!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (chat.lastMessageAt != null)
                      Text(
                        '${chat.lastMessageAt!.hour}:${chat.lastMessageAt!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showArchivedMeetups() {
    _loadArchivedMeetups().then((_) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Архивные встречи',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _archivedMeetups.isEmpty
                            ? const Center(
                                child: Text(
                                  'Нет архивных встреч',
                                  style: TextStyle(fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _archivedMeetups.length,
                                itemBuilder: (context, index) {
                                  final chat = _archivedMeetups[index];
                                  return _buildChatTile(
                                    chat,
                                    showActions: false,
                                    isArchived: true,
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Встречи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive),
            onPressed: _showArchivedMeetups,
            tooltip: 'Архивные встречи',
          ),
        ],
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

                  // Проверяем статус встречи
                  if (updatedChat.meetupStatus == MeetupStatus.completed) {
                    print(
                        'Получено обновление встречи ${updatedChat.chatId} со статусом completed');

                    // Удаляем встречу из активных, если она была переведена в статус completed
                    final existingIndex = _chats.indexWhere(
                        (chat) => chat.chatId == updatedChat.chatId);
                    if (existingIndex != -1) {
                      setState(() {
                        _chats.removeAt(existingIndex);
                      });
                      print(
                          'Удалена встреча ${updatedChat.chatId} из активных (переведена в completed)');
                    }
                  } else {
                    // Обрабатываем обновление для активной встречи
                    final existingIndex = _chats.indexWhere(
                        (chat) => chat.chatId == updatedChat.chatId);

                    if (existingIndex != -1) {
                      setState(() {
                        _chats[existingIndex] = updatedChat;
                      });
                      print(
                          'Обновлена информация о встрече ${updatedChat.chatId}');
                    } else {
                      // Проверяем, не является ли это новой встречей
                      setState(() {
                        _chats.add(updatedChat);
                      });
                      print('Добавлена новая встреча ${updatedChat.chatId}');

                      // Загружаем информацию об участниках для новой встречи
                      _chatService
                          .getChatParticipantsInfo(updatedChat.chatId)
                          .then((participants) {
                        _chatParticipants[updatedChat.chatId] = participants;
                      }).catchError((e) {
                        print(
                            'Ошибка при загрузке участников для новой встречи: $e');
                        _chatParticipants[updatedChat.chatId] = [];
                      });
                    }
                  }
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChatList(_chats),
                    _buildChatList(_invitedMeetups, showActions: true),
                  ],
                );
              },
            ),
    );
  }
}
