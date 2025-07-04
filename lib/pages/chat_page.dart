import 'package:flutter/material.dart';
import '../widgets/custom_notification.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../api_services/chat_service.dart';
import '../api_services/auth_service/auth_provider.dart';
import 'chat_detail_page.dart';
import '../models/chat_participant_info.dart';
import '../nav_service/navigation_provider.dart';
import '../pages/Example.dart';
import '../api_services/place_serice/place.dart';
import '../api_services/map_service/location.dart';
import '../pages/create_meetup_page.dart';
import '../api_services/meetup_service/meetup_service.dart';

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

  // Добавляем Map для хранения состояния загрузки маршрута для каждого чата
  final Map<int, bool> _isRouteLoading = {};

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
        CustomNotification.show(context, 'Ошибка подключения к чату: $e');
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

          // Копируем информацию из meetup в chat, если она отсутствует в chat
          Chat updatedChat = chat;

          // Копируем scheduledTime, если он есть в meetup, но отсутствует в chat
          if (updatedChat.scheduledTime == null &&
              meetup.scheduledTime != null) {
            print(
                'Копируем scheduledTime из meetup в chat: ${meetup.scheduledTime}');
            updatedChat =
                updatedChat.copyWith(scheduledTime: meetup.scheduledTime);
          }

          // Копируем информацию о месте, если она есть в meetup, но отсутствует в chat
          if (updatedChat.placeName == null && meetup.placeName != null) {
            print('Копируем информацию о месте из meetup в chat');
            updatedChat = updatedChat.copyWith(
                placeName: meetup.placeName,
                placeAddress: meetup.placeAddress,
                latitude: meetup.latitude,
                longitude: meetup.longitude,
                placeImageUrl: meetup.placeImageUrl);
          }

          chatsWithMessages.add(updatedChat);

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

        // Фильтруем приглашения, исключая завершенные и отмененные встречи
        invitedMeetups = invitedMeetups
            .where((chat) =>
                chat.meetupStatus != MeetupStatus.completed &&
                chat.meetupStatus != MeetupStatus.cancelled)
            .toList();
        print(
            'После фильтрации осталось приглашений: ${invitedMeetups.length}');

        // Обрабатываем приглашения
        for (int i = 0; i < invitedMeetups.length; i++) {
          var chat = invitedMeetups[i];
          print('Приглашение $i до обработки:');
          print('- ID: ${chat.chatId}');
          print('- Название: ${chat.name}');
          print('- Время: ${chat.scheduledTime}');
          print('- Статус: ${chat.meetupStatus}');
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
        CustomNotification.show(context, 'Ошибка загрузки данных: $e');
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
        CustomNotification.show(context, 'Ошибка загрузки архивных встреч: $e');
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
          CustomNotification.show(context, 'Вы приняли приглашение на встречу');
        }
      } else {
        await _chatService.declineMeetupInvitation(chat.meetupId!);
        if (mounted) {
          CustomNotification.show(
              context, 'Вы отклонили приглашение на встречу');
        }
      }

      // Обновляем данные после успешного ответа
      await _loadData();
    } catch (e) {
      print('Ошибка при обработке приглашения:');
      print(e);

      if (mounted) {
        CustomNotification.show(context,
            'Ошибка при ${accept ? 'принятии' : 'отклонении'} приглашения: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildChatList(List<Chat> chats, {bool showActions = false}) {
    // Фильтруем чаты по статусу
    List<Chat> filteredChats = chats;

    // Если это приглашения (showActions = true), отфильтровываем завершенные и отмененные встречи
    if (showActions) {
      filteredChats = chats
          .where((chat) =>
              chat.meetupStatus != MeetupStatus.completed &&
              chat.meetupStatus != MeetupStatus.cancelled)
          .toList();

      print(
          'Отфильтровано приглашений: было ${chats.length}, стало ${filteredChats.length}');
      for (var chat in filteredChats) {
        print('- Приглашение ${chat.chatId}, статус: ${chat.meetupStatus}');
      }
    }

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
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: processedChats.length,
      itemBuilder: (context, index) {
        final chat = processedChats[index];
        if (showActions) {
          print('Приглашение #$index:');
          print('- ID: ${chat.chatId}');
          print('- Название: ${chat.name}');
          print('- Время: ${chat.scheduledTime}');
          print('- Статус: ${chat.meetupStatus}');
          print('- Последнее сообщение: ${chat.lastMessageContent}');
        }
        return _buildChatTile(chat,
            showActions: showActions, isArchived: false);
      },
    );
  }

  Widget _buildChatTile(Chat chat,
      {bool showActions = false, bool isArchived = false}) {
    print('Building chat tile for chat: ${chat.name}');
    print('- Place name: ${chat.placeName}');
    print('- Place address: ${chat.placeAddress}');
    print('- Latitude: ${chat.latitude}');
    print('- Longitude: ${chat.longitude}');
    print('- Place image URL: ${chat.placeImageUrl}');

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

    final formattedDate = chat.scheduledTime != null
        ? _formatDateTime(chat.scheduledTime!)
        : 'Время не указано';

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
                // Добавляем кнопку с тремя точками только для активных встреч и только для организатора
                if (!showActions && !isArchived)
                  FutureBuilder<int?>(
                    future: Provider.of<AuthProvider>(context, listen: false)
                        .getUserId(),
                    builder: (context, snapshot) {
                      // Проверяем, является ли текущий пользователь организатором встречи
                      final isCreator =
                          snapshot.hasData && snapshot.data == chat.createdById;

                      // Показываем кнопку только если пользователь - организатор
                      if (isCreator) {
                        return PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (String value) async {
                            if (value == 'edit') {
                              // Редактирование встречи
                              _editMeetup(chat);
                            } else if (value == 'delete') {
                              // Удаление встречи
                              _deleteMeetup(chat);
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Редактировать'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Удалить',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Если пользователь не организатор, не показываем кнопку
                        return const SizedBox.shrink();
                      }
                    },
                  ),
              ],
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
                if (chat.placeName != null || chat.placeAddress != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (chat.placeImageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              chat.placeImageUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.place, size: 30),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.place, size: 30),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chat.placeName ?? 'Место встречи',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (chat.placeAddress != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  chat.placeAddress!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Добавляем кнопку маршрута справа от информации о месте
                        if (!isArchived &&
                            chat.latitude != null &&
                            chat.longitude != null)
                          _isRouteLoading[chat.chatId] == true
                              ? Container(
                                  width: 48,
                                  height: 48,
                                  padding: const EdgeInsets.all(12),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.directions_walk,
                                      color: Colors.blue),
                                  onPressed: () => _navigateToMap(chat),
                                  tooltip: 'Построить маршрут',
                                ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
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
            onTap: showActions
                ? null
                : () => _onChatTap(chat, isArchived: isArchived),
          ),
          if (showActions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.check, color: Colors.green, size: 24),
                    onPressed: () => _respondToInvitation(chat, true),
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 24),
                    onPressed: () => _respondToInvitation(chat, false),
                  ),
                ],
              ),
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

  Future<void> _editMeetup(Chat chat) async {
    try {
      setState(() => _isLoading = true);

      // Получаем данные встречи
      final meetupId = chat.meetupId;
      if (meetupId == null) {
        throw Exception('ID встречи не найден');
      }

      // Создаем объект с данными для редактирования
      final meetupToEdit = {
        'meetupId': meetupId,
        'name': chat.name,
        'description': chat.description,
        'scheduledTime': chat.scheduledTime?.toIso8601String(),
        'participants': chat.participants
            .map((p) => {
                  'userId': p.userId,
                  'username': p.name,
                  'avatarUrl': p.avatarUrl,
                  'status': p.role,
                })
            .toList(),
        'place': {
          'name': chat.placeName,
          'address': chat.placeAddress,
          'latitude': chat.latitude,
          'longitude': chat.longitude,
          'imageUrl': chat.placeImageUrl,
        },
      };

      // Создаем объект с данными о месте
      // Поскольку в классе Chat нет свойства placeId, используем ID из объекта place в meetupToEdit
      // или null, если ID места не найден
      final selectedPlace = {
        'id': null, // ID места будет определен на странице редактирования
        'name': chat.placeName ?? 'Неизвестное место',
        'address': chat.placeAddress,
        'latitude': chat.latitude,
        'longitude': chat.longitude,
        'imageUrl': chat.placeImageUrl,
      };

      setState(() => _isLoading = false);

      // Переходим на страницу редактирования встречи
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateMeetupPage(
            selectedPlace: selectedPlace,
            meetupToEdit: meetupToEdit,
            isEditing: true,
          ),
        ),
      );

      // Обновляем данные после возвращения
      if (result != null) {
        _loadData();
      }
    } catch (e) {
      print('Ошибка при редактировании встречи: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(
            context, 'Ошибка при редактировании встречи: $e');
      }
    }
  }

  Future<void> _deleteMeetup(Chat chat) async {
    try {
      // Показываем диалог подтверждения
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удаление встречи'),
          content: const Text('Вы уверены, что хотите удалить эту встречу?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isLoading = true);

      final meetupId = chat.meetupId;
      if (meetupId == null) {
        throw Exception('ID встречи не найден');
      }

      // Получаем сервис для работы с встречами
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final meetupService = MeetupService(authProvider);

      // Отменяем встречу
      await meetupService.cancelMeetup(meetupId);

      if (mounted) {
        CustomNotification.show(context, 'Встреча успешно удалена');
        // Обновляем список встреч
        _loadData();
      }
    } catch (e) {
      print('Ошибка при удалении встречи: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotification.show(context, 'Ошибка при удалении встречи: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToMap(Chat chat) async {
    if (chat.latitude != null && chat.longitude != null) {
      print('_navigateToMap: Начинаем построение маршрута');
      print(
          '_navigateToMap: Данные места - lat: ${chat.latitude}, long: ${chat.longitude}, name: ${chat.placeName ?? chat.name}');

      // Проверяем валидность координат
      if (chat.latitude == 0.0 || chat.longitude == 0.0) {
        print('_navigateToMap: ОШИБКА! Координаты места равны 0');
        CustomNotification.show(
            context, 'Ошибка: координаты места встречи некорректны');
        return;
      }

      // Устанавливаем состояние загрузки для этого чата
      setState(() {
        _isRouteLoading[chat.chatId] = true;
      });

      try {
        // Сначала строим маршрут, НЕ переключаясь на вкладку карты
        final success = await ExamplePage.directBuildRoute(
            context,
            chat.latitude!,
            chat.longitude!,
            chat.placeName ?? chat.name,
            false // Не переключаться автоматически на вкладку карты
            );

        print('_navigateToMap: Результат построения маршрута: $success');

        // Если маршрут успешно построен, переключаемся на вкладку карты
        if (success) {
          // Переключаемся на вкладку карты
          final navigation = NavigationProvider.of(context);
          if (navigation != null && mounted) {
            navigation.onNavigate(0);
            print(
                '_navigateToMap: Переключились на вкладку карты после построения маршрута');
          } else {
            print(
                '_navigateToMap: NavigationProvider не найден или виджет размонтирован');
          }
        } else {
          print(
              '_navigateToMap: Маршрут не был построен, остаемся на текущем экране');
          if (mounted) {
            CustomNotification.show(context, 'Не удалось построить маршрут');
          }
        }
      } catch (e) {
        print('_navigateToMap: Ошибка при построении маршрута: $e');

        if (mounted) {
          CustomNotification.show(
              context, 'Ошибка при построении маршрута: ${e.toString()}');
        }

        // Если произошла ошибка, сохраняем данные маршрута, но не переключаемся на карту
        ExamplePage.destinationLat = chat.latitude;
        ExamplePage.destinationLng = chat.longitude;
        ExamplePage.destinationName = chat.placeName ?? chat.name;
        ExamplePage.pendingRouteRequest = true;
        print('_navigateToMap: Сохранены данные маршрута в ExamplePage');
      } finally {
        // Сбрасываем состояние загрузки
        if (mounted) {
          setState(() {
            _isRouteLoading[chat.chatId] = false;
          });
        }
      }
    } else {
      print('_navigateToMap: Координаты места не указаны');
      CustomNotification.show(context, 'Место встречи не указано');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Встречи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить данные',
          ),
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
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.black,
          indicatorColor: Theme.of(context).colorScheme.primary,
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

                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: TabBarView(
                    controller: _tabController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildChatList(_chats),
                      _buildChatList(_invitedMeetups, showActions: true),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
