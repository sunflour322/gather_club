import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gather_club/api_services/user_location_service.dart';
import '../widgets/custom_notification.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../api_services/chat_service.dart';
import '../api_services/auth_service/auth_provider.dart';
import '../widgets/participants_dialog.dart';
import '../models/chat_participant_info.dart';
import '../theme/app_theme.dart';
import '../nav_service/navigation_provider.dart';
import '../pages/Example.dart';
import '../api_services/customization_service.dart';
import 'package:gather_club/pages/Example.dart';

class ChatDetailPage extends StatefulWidget {
  final Chat chat;
  final bool isArchived;

  const ChatDetailPage({
    super.key,
    required this.chat,
    this.isArchived = false,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ChatMessage? _replyTo;
  bool _isTyping = false;
  late final ChatService _chatService;
  int _currentUserId = 0;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  Timer? _typingTimer;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  static const int _pageSize = 20;
  List<ChatParticipantInfo> _participants = [];
  Timer? _checkTimeTimer;
  bool _showCheckButton = false;
  Duration? _timeRemaining;
  String? _chatThemeUrl;
  late AnimationController _starAnimationController;
  late Animation<double> _starAnimation;
  late CustomizationService _customizationService;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _chatService = ChatService(authProvider);
    _customizationService = CustomizationService(authProvider);
    _initWebSocket();
    _getCurrentUser();
    _loadInitialData();

    _starAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _starAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _starAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.chat.scheduledTime != null) {
      _checkTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateCheckButtonVisibility();
      });
    }
  }

  void _updateCheckButtonVisibility() {
    if (widget.chat.scheduledTime == null) return;

    final now = DateTime.now();
    final scheduledTime = widget.chat.scheduledTime!;
    final halfHour = const Duration(minutes: 30);

    // Показываем кнопку за 30 минут до и после встречи
    final shouldShow = now.isAfter(scheduledTime.subtract(halfHour)) &&
        now.isBefore(scheduledTime.add(halfHour));

    if (mounted) {
      setState(() {
        _showCheckButton = shouldShow;
        _timeRemaining = scheduledTime.add(halfHour).difference(now);
      });
    }
  }

  Widget _buildLocationCheckButton() {
    final remainingText = _timeRemaining != null
        ? '${_timeRemaining!.inMinutes}:${(_timeRemaining!.inSeconds % 60).toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        remainingText,
        style: TextStyle(
          color: AppTheme.textSecondaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _getCurrentUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = await authProvider.getUserId();

    // Загружаем тему чата
    if (_currentUserId != 0) {
      try {
        final chatThemeUrl =
            await _customizationService.getActiveChatThemeUrl(_currentUserId);
        if (mounted) {
          setState(() {
            _chatThemeUrl = chatThemeUrl;
          });
        }
      } catch (e) {
        print('Ошибка при загрузке темы чата: $e');
      }
    }
  }

  Future<void> _initWebSocket() async {
    try {
      // Сначала подключаемся к WebSocket
      await _chatService.connectToWebSocket();

      // Для архивных встреч не подписываемся на сообщения через WebSocket
      if (widget.isArchived) {
        print('Архивная встреча: пропускаем подписку на WebSocket');
        return;
      }

      // Добавляем задержку перед подпиской, чтобы убедиться, что WebSocket подключен
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Используем механизм повторных попыток для подписки
        int retryCount = 0;
        const maxRetries = 3;
        bool subscribed = false;

        while (!subscribed && retryCount < maxRetries && mounted) {
          try {
            await _chatService.subscribeToChat(
              widget.chat.chatId,
              onTyping: (userId) {
                if (mounted) {
                  print('Пользователь $userId печатает...');
                  _handleTyping(userId);
                }
              },
              onRead: (userId) {
                if (mounted) {
                  print('Пользователь $userId прочитал сообщения');
                  _handleRead(userId);
                }
              },
            );
            subscribed = true;
            print('Успешно подписались на чат ${widget.chat.chatId}');
          } catch (e) {
            retryCount++;
            print('Ошибка при подписке на чат (попытка $retryCount): $e');

            if (retryCount < maxRetries) {
              // Ждем перед повторной попыткой
              await Future.delayed(Duration(milliseconds: 300 * retryCount));

              // Пытаемся переподключить WebSocket перед повторной попыткой
              if (retryCount > 1) {
                try {
                  await _chatService.connectToWebSocket();
                } catch (wsError) {
                  print('Ошибка при переподключении WebSocket: $wsError');
                }
              }
            }
          }
        }

        if (!subscribed && mounted) {
          // Если после всех попыток не удалось подписаться, показываем сообщение
          CustomNotification.show(
            context,
            'Не удалось подключиться к чату. Сообщения могут отображаться некорректно.',
          );
        }
      }
    } catch (e) {
      print('Ошибка при инициализации WebSocket:');
      print(e);
      if (mounted) {
        CustomNotification.show(
          context,
          'Ошибка подключения к чату: $e',
        );
      }
    }
  }

  void _handleTyping(int userId) {
    if (userId != _currentUserId && mounted) {
      setState(() {
        _isTyping = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
          });
        }
      });
    }
  }

  void _handleRead(int userId) {
    // Обработка прочтения будет происходить автоматически через стрим
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text;
    final replyToId = _replyTo?.messageId;
    _messageController.clear();
    _replyTo = null;

    try {
      print('Отправка сообщения: $message');
      print('В ответ на: $replyToId');

      await _chatService.sendMessage(
        widget.chat.chatId,
        message,
        replyToId: replyToId,
      );

      print('Сообщение отправлено успешно');
    } catch (e) {
      print('Ошибка при отправке сообщения:');
      print(e);
      if (mounted) {
        CustomNotification.show(
          context,
          'Ошибка отправки сообщения: $e',
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _checkTimeTimer?.cancel();
    _starAnimationController.dispose();
    try {
      _chatService.unsubscribeFromChat(widget.chat.chatId);
    } catch (e) {
      print('Ошибка при отписке от чата ${widget.chat.chatId}: $e');
    }
    super.dispose();
  }

  Widget _buildMessageItem(ChatMessage message, bool isCurrentUser) {
    final showAvatar = !isCurrentUser && message.senderAvatar != null;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser && showAvatar)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(message.senderAvatar!),
                ),
              ),
            if (!isCurrentUser && !showAvatar)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.accentColor.withOpacity(0.7),
                  child: Text(
                    message.senderName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isCurrentUser ? AppTheme.accentColor : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isCurrentUser)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (message.replyToId != null)
                      _buildReplyPreview(message.replyToId!, isCurrentUser),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isCurrentUser
                            ? Colors.white
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.sentAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isCurrentUser
                                ? Colors.white.withOpacity(0.9)
                                : AppTheme.textSecondaryColor,
                          ),
                        ),
                        if (message.readAt != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.done_all,
                              size: 12,
                              color: isCurrentUser
                                  ? Colors.white.withOpacity(0.9)
                                  : AppTheme.textSecondaryColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(int replyToId, bool isCurrentUser) {
    // Сначала проверяем в имеющихся сообщениях
    ChatMessage? replyToMessage;
    for (var msg in _messages) {
      if (msg.messageId == replyToId) {
        replyToMessage = msg;
        break;
      }
    }

    // Если нашли сообщение, строим превью
    if (replyToMessage != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? Colors.white.withOpacity(0.2)
              : AppTheme.accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replyToMessage.senderName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isCurrentUser ? Colors.white : AppTheme.textPrimaryColor,
              ),
            ),
            Text(
              replyToMessage.content,
              style: TextStyle(
                fontSize: 12,
                color: isCurrentUser
                    ? Colors.white.withOpacity(0.9)
                    : AppTheme.textSecondaryColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Если не нашли в имеющихся сообщениях, показываем заглушку
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Colors.white.withOpacity(0.2)
            : AppTheme.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ответ на сообщение',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isCurrentUser ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
          Text(
            'Сообщение недоступно',
            style: TextStyle(
              fontSize: 12,
              color: isCurrentUser
                  ? Colors.white.withOpacity(0.9)
                  : AppTheme.textSecondaryColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Ответить'),
              onTap: () {
                setState(() => _replyTo = message);
                Navigator.pop(context);
              },
            ),
            if (message.senderId == _currentUserId)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Удалить'),
                onTap: () {
                  // TODO: Добавить функционал удаления
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Копировать'),
              onTap: () {
                // TODO: Добавить функционал копирования
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isArchived) {
        // Для архивных встреч загружаем только участников
        await _loadParticipants();
      } else {
        // Для обычных встреч загружаем и сообщения, и участников
        await Future.wait([
          _loadMessages(),
          _loadParticipants(),
        ]);
      }
    } catch (e) {
      print('Ошибка при загрузке данных: $e');
      if (mounted) {
        CustomNotification.show(
          context,
          'Ошибка загрузки данных: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadParticipants() async {
    try {
      // Для архивных встреч участники уже должны быть в объекте chat
      if (widget.isArchived && widget.chat.participants.isNotEmpty) {
        print('Архивная встреча: используем предзагруженных участников');

        // Создаем список для хранения всех участников
        final List<ChatParticipantInfo> allParticipants = [];

        // Флаг для отслеживания, добавлен ли организатор
        bool creatorIncluded = false;

        // Преобразуем ChatParticipant в ChatParticipantInfo
        for (var p in widget.chat.participants) {
          final participantInfo = ChatParticipantInfo(
            userId: p.userId,
            username: p.name,
            avatarUrl: p.avatarUrl,
            // Определяем роль: если это создатель, то "admin", иначе "participant"
            role: p.userId == widget.chat.createdById ? 'admin' : 'participant',
            joinedAt: p.joinedAt,
          );

          allParticipants.add(participantInfo);

          // Проверяем, является ли этот участник организатором
          if (p.userId == widget.chat.createdById) {
            creatorIncluded = true;
          }
        }

        // Если организатор не включен в список участников, добавляем его
        if (!creatorIncluded) {
          print('Добавляем организатора в список участников');
          allParticipants.add(
            ChatParticipantInfo(
              userId: widget.chat.createdById,
              username: widget.chat.createdByName,
              avatarUrl: widget.chat.createdByAvatar,
              role: 'admin',
              joinedAt: widget.chat.createdAt,
            ),
          );
        }

        if (mounted) {
          setState(() => _participants = allParticipants);
        }

        // Логируем участников для отладки
        print(
            'Загружено ${allParticipants.length} участников архивной встречи:');
        for (var i = 0; i < allParticipants.length; i++) {
          print(
              '- Участник #$i: ${allParticipants[i].username} (ID: ${allParticipants[i].userId}, роль: ${allParticipants[i].role})');
        }

        return;
      }

      // Для обычных встреч загружаем участников через API
      final participants =
          await _chatService.getChatParticipantsInfo(widget.chat.chatId);

      // Проверяем, есть ли организатор в списке участников
      bool creatorIncluded =
          participants.any((p) => p.userId == widget.chat.createdById);

      // Если организатора нет в списке, добавляем его
      if (!creatorIncluded) {
        print('Добавляем организатора в список участников для обычной встречи');
        participants.add(
          ChatParticipantInfo(
            userId: widget.chat.createdById,
            username: widget.chat.createdByName,
            avatarUrl: widget.chat.createdByAvatar,
            role: 'admin',
            joinedAt: widget.chat.createdAt,
          ),
        );
      }

      if (mounted) {
        setState(() => _participants = participants);
      }
    } catch (e) {
      print('Ошибка при загрузке участников: $e');
    }
  }

  Future<void> _loadMessages() async {
    // Не загружаем сообщения для архивных встреч
    if (widget.isArchived) {
      print('Архивная встреча: пропускаем загрузку сообщений');
      return;
    }

    try {
      final messages = await _chatService.getChatMessages(
        widget.chat.chatId,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка при загрузке сообщений: $e');
      rethrow;
    }
  }

  void _showParticipantsDialog() {
    showDialog(
      context: context,
      builder: (context) => ParticipantsDialog(participants: _participants),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTime = DateTime.now();
    final isActivePeriod = widget.chat.scheduledTime != null &&
        currentTime.isAfter(
            widget.chat.scheduledTime!.subtract(const Duration(minutes: 30))) &&
        currentTime.isBefore(
            widget.chat.scheduledTime!.add(const Duration(minutes: 30)));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: isActivePeriod
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accentColor.withOpacity(0.1),
                  Colors.white.withOpacity(0.3),
                  AppTheme.accentColor.withOpacity(0.1),
                ],
              )
            : null,
      ),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    print('Building ChatDetailPage for chat: ${widget.chat.name}');
    print('- Place name: ${widget.chat.placeName}');
    print('- Place address: ${widget.chat.placeAddress}');
    print('- Latitude: ${widget.chat.latitude}');
    print('- Longitude: ${widget.chat.longitude}');
    print('- Place image URL: ${widget.chat.placeImageUrl}');
    print('- Chat theme URL: $_chatThemeUrl');

    return Scaffold(
      // Применяем фоновое изображение темы чата, если оно есть
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: _chatThemeUrl != null,
      appBar: AppBar(
        title: Text(widget.chat.name),
        actions: [
          if (widget.isArchived)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.archive, color: AppTheme.textSecondaryColor),
            ),
          if (widget.chat.scheduledTime != null && _showCheckButton)
            _buildLocationCheckButton(),
          if (widget.chat.scheduledTime != null && _showCheckButton)
            AnimatedBuilder(
              animation: _starAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _starAnimation.value,
                  child: IconButton(
                    icon: Image.asset('assets/star.png', width: 24, height: 24),
                    onPressed: () async {
                      print(
                          '[${DateTime.now()}] Начало обработки нажатия кнопки звезды');

                      if (_currentUserId == null) {
                        print(
                            '[${DateTime.now()}] Ошибка: _currentUserId равен null');
                        CustomNotification.show(
                          context,
                          'Не удалось определить пользователя',
                        );
                        return;
                      }

                      print(
                          '[${DateTime.now()}] ID пользователя: $_currentUserId');

                      try {
                        final locationService =
                            Provider.of<UserLocationService>(
                          context,
                          listen: false,
                        );

                        print(
                            '[${DateTime.now()}] Запрос текущего местоположения...');
                        final currentLocation = await locationService
                            .getLastLocation(_currentUserId!);

                        if (currentLocation == null) {
                          print(
                              '[${DateTime.now()}] Ошибка: не удалось получить местоположение');
                          CustomNotification.show(
                            context,
                            'Не удалось получить текущее местоположение',
                          );
                          return;
                        }

                        print(
                            '[${DateTime.now()}] Получено местоположение: lat=${currentLocation.latitude}, lon=${currentLocation.longitude}');
                        print(
                            '[${DateTime.now()}] Вызов API проверки местоположения...');

                        if (widget.chat.meetupId == null) {
                          CustomNotification.show(
                            context,
                            'Ошибка: ID встречи не найден',
                          );
                          return;
                        }

                        final result = await _chatService.checkMeetupLocation(
                          widget.chat.meetupId!, // Гарантировано не null
                          _currentUserId,
                          currentLocation.latitude,
                          currentLocation.longitude,
                        );

                        print(
                            '[${DateTime.now()}] Результат API: success=${result.success}, message=${result.message}');

                        CustomNotification.show(
                          context,
                          result.message!,
                        );

                        if (result.success) {
                          print(
                              '[${DateTime.now()}] Успешная проверка местоположения');
                          // Закрываем страницу при успешном зачислении звезды
                          Navigator.of(context).pop();
                        } else {
                          print(
                              '[${DateTime.now()}] Ошибка проверки местоположения: ${result.message}');
                        }
                      } catch (e) {
                        print(
                            '[${DateTime.now()}] Исключение при проверке местоположения: $e');
                        CustomNotification.show(
                          context,
                          'Ошибка проверки местоположения: $e',
                        );
                      }
                    },
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: _showParticipantsDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Фоновое изображение на весь экран с эффектом размытия
          if (_chatThemeUrl != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(_chatThemeUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          // Основной контент с отступом сверху, чтобы не перекрывать AppBar
          Column(
            children: [
              // Добавляем отступ сверху, чтобы контент не уезжал под AppBar
              if (_chatThemeUrl != null)
                SizedBox(
                    height:
                        MediaQuery.of(context).padding.top + kToolbarHeight),
              if (widget.chat.placeName != null ||
                  widget.chat.placeAddress != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.accentColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (widget.chat.placeImageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.chat.placeImageUrl!,
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
                              widget.chat.placeName ?? 'Место встречи',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (widget.chat.placeAddress != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.chat.placeAddress!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                            if (widget.chat.scheduledTime != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatDateTime(widget.chat.scheduledTime!),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: widget.isArchived
                    ? _buildArchivedChatView()
                    : StreamBuilder<List<ChatMessage>>(
                        stream: _chatService
                            .getChatMessagesStream(widget.chat.chatId),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Ошибка: ${snapshot.error}'));
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final messages = snapshot.data!;
                          print('Обновление UI: ${messages.length} сообщений');

                          // Обновляем локальный список сообщений для корректного отображения ответов
                          if (mounted && messages.isNotEmpty) {
                            _messages = messages;
                          }

                          // Автоматическая прокрутка при новых сообщениях
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              // Берем сообщения с конца списка
                              final message =
                                  messages[messages.length - 1 - index];
                              final isCurrentUser =
                                  message.senderId == _currentUserId;
                              return _buildMessageItem(message, isCurrentUser);
                            },
                          );
                        },
                      ),
              ),
              if (!widget.isArchived)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Введите сообщение...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) =>
                              _chatService.notifyTyping(widget.chat.chatId),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage,
                        color: AppTheme.accentColor,
                      ),
                    ],
                  ),
                ),
              if (_isTyping && !widget.isArchived)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Печатает...',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_replyTo != null && !widget.isArchived)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: AppTheme.accentColor.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.reply, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _replyTo!.senderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _replyTo!.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.isArchived)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppTheme.accentColor.withOpacity(0.1),
                  child: Text(
                    'Эта встреча завершена. Отправка сообщений недоступна.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedChatView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.archive_outlined,
            size: 64,
            color: AppTheme.accentColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Архивная встреча',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Состоялась ${widget.chat.scheduledTime != null ? _formatDateTime(widget.chat.scheduledTime!) : "ранее"}',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 24),
          const Text(
            'Сообщения этой встречи недоступны',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String timeStr =
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (date == today) {
      return 'сегодня в $timeStr';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'вчера в $timeStr';
    } else {
      return '${dateTime.day}.${dateTime.month}.${dateTime.year} в $timeStr';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'вчера';
    } else {
      return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}';
    }
  }
}
