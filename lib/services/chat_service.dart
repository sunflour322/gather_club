import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:http/http.dart' as http;
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../models/chat_participant_info.dart';
import '../auth_service/auth_provider.dart';
import 'dart:async';

typedef StompUnsubscribeFn = void Function();
typedef MessageCallback = void Function(ChatMessage message);
typedef TypingCallback = void Function(int userId);
typedef ReadCallback = void Function(int userId);

class ChatService {
  static const String baseUrl = 'http://212.67.8.92:8080';
  static const String wsUrl = 'ws://212.67.8.92:8080/ws/websocket';

  final AuthProvider _authProvider;
  StompClient? _stompClient;
  final Map<String, StompUnsubscribeFn> _subscriptions = {};
  final _chatUpdateController = StreamController<Chat>.broadcast();

  // Добавляем контроллер для сообщений чата
  final Map<int, StreamController<List<ChatMessage>>> _messageControllers = {};

  static const int maxReconnectAttempts = 3;
  int _reconnectAttempts = 0;
  bool _isReconnecting = false;

  ChatService(this._authProvider);

  // Получаем стрим сообщений для конкретного чата
  Stream<List<ChatMessage>> getChatMessagesStream(int chatId) {
    _messageControllers[chatId] ??=
        StreamController<List<ChatMessage>>.broadcast();
    return _messageControllers[chatId]!.stream;
  }

  // REST API методы

  Future<List<Chat>> getUserChats() async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Получаем активные встречи пользователя...');
      final response = await http.get(
        Uri.parse('$baseUrl/meetups/active'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка загрузки активных встреч: ${response.statusCode}');
      }

      final List<dynamic> meetupsJson = jsonDecode(response.body);
      print('Получено активных встреч: ${meetupsJson.length}');

      final chats = meetupsJson.map((json) {
        // Преобразуем meetup в формат chat для совместимости
        final Map<String, dynamic> chatJson = {
          ...Map<String, dynamic>.from(json as Map),
          'chatId': json['meetupId'],
        };
        return Chat.fromJson(chatJson);
      }).toList();

      print('Преобразовано активных встреч: ${chats.length}');
      for (var chat in chats) {
        print('Активная встреча: ${chat.name}');
        print('- ID чата: ${chat.chatId}');
        print('- ID встречи: ${chat.meetupId}');
        print('- Тип: ${chat.type}');
        print('- Статус: ${chat.meetupStatus}');
      }

      return chats;
    } catch (e, stackTrace) {
      print('Ошибка при получении активных встреч:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  Future<Chat> createChat(Map<String, dynamic> chatRequest) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final response = await http.post(
      Uri.parse('$baseUrl/chats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(chatRequest),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Chat.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Ошибка создания чата: ${response.statusCode}');
    }
  }

  Future<Chat> getChatById(int chatId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final response = await http.get(
      Uri.parse('$baseUrl/chats/$chatId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return Chat.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Ошибка получения чата: ${response.statusCode}');
    }
  }

  Future<List<ChatMessage>> getChatMessages(int chatId,
      {int limit = 50, int offset = 0}) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    print('Загрузка сообщений для чата $chatId');
    print('Используемый токен: $token');

    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/chats/$chatId/messages?page=${offset ~/ limit}&size=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print(chatId);
      print('Ответ сервера: ${response.statusCode}');
      print('Тело ответа: ${response.body}');
      print('Заголовки ответа: ${response.headers}');

      if (response.statusCode == 200) {
        final List<dynamic> messagesJson = jsonDecode(response.body);
        return messagesJson.map((json) => ChatMessage.fromJson(json)).toList();
      } else if (response.statusCode == 403) {
        print(
            'Ошибка доступа: возможно, у пользователя нет прав на просмотр сообщений этого чата');
        throw Exception('У вас нет доступа к сообщениям этого чата');
      } else {
        print('Неожиданная ошибка при загрузке сообщений');
        throw Exception(
            'Ошибка загрузки сообщений: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Исключение при загрузке сообщений:');
      print(e);
      print('Stack trace:');
      print(stackTrace);
      rethrow;
    }
  }

  Future<void> addParticipant(int chatId, int userId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final response = await http.post(
      Uri.parse('$baseUrl/chats/$chatId/participants'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка добавления участника: ${response.statusCode}');
    }
  }

  Future<void> removeParticipant(int chatId, int userId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final response = await http.delete(
      Uri.parse('$baseUrl/chats/$chatId/participants/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка удаления участника: ${response.statusCode}');
    }
  }

  Future<void> deleteChat(int chatId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final response = await http.delete(
      Uri.parse('$baseUrl/chats/$chatId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка удаления чата: ${response.statusCode}');
    }
  }

  Future<List<Chat>> getInvitedMeetups() async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Получаем приглашения на встречи...');
      final response = await http.get(
        Uri.parse('$baseUrl/meetups/invited'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки приглашений: ${response.statusCode}');
      }

      final List<dynamic> meetupsJson = jsonDecode(response.body);
      print('Получено приглашений: ${meetupsJson.length}');

      // Детальное логирование для отладки приглашений
      print('Содержимое приглашений (JSON):');
      for (var i = 0; i < meetupsJson.length; i++) {
        print('Приглашение #$i JSON: ${meetupsJson[i]}');
      }

      final chats = meetupsJson.map((json) {
        // Преобразуем meetup в формат chat для совместимости
        final Map<String, dynamic> chatJson = {
          ...Map<String, dynamic>.from(json as Map),
          'chatId': json['meetupId'],
          // Принудительно устанавливаем lastMessageContent в null для приглашений
          'lastMessageContent': null,
        };
        return Chat.fromJson(chatJson);
      }).toList();

      print('Преобразовано приглашений: ${chats.length}');
      for (var chat in chats) {
        print('Приглашение: ${chat.name}');
        print('- ID чата: ${chat.chatId}');
        print('- ID встречи: ${chat.meetupId}');
        print('- Тип: ${chat.type}');
        print('- Время встречи: ${chat.scheduledTime}');
        print('- Организатор: ${chat.createdByName}');
        print('- Участники: ${chat.participants.length}');
        print('- Последнее сообщение: ${chat.lastMessageContent}');
      }

      return chats;
    } catch (e, stackTrace) {
      print('Ошибка при получении приглашений:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  Future<void> acceptMeetupInvitation(int meetupId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      print('Принимаем приглашение на встречу $meetupId...');
      final response = await http.post(
        Uri.parse('$baseUrl/meetups/$meetupId/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка при принятии приглашения: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Ошибка при принятии приглашения:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  Future<void> declineMeetupInvitation(int meetupId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      print('Отклоняем приглашение на встречу $meetupId...');
      final response = await http.post(
        Uri.parse('$baseUrl/meetups/$meetupId/decline'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка при отклонении приглашения: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Ошибка при отклонении приглашения:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  // WebSocket методы

  Future<void> connectToWebSocket() async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    if (_stompClient?.connected ?? false) return;

    print('Connecting to WebSocket with token: $token');

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onWebSocketError: (error) {
          print('WebSocket error: $error');
          _reconnectWebSocket();
        },
        onStompError: (error) {
          print('STOMP error: ${error.body}');
          _reconnectWebSocket();
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    try {
      _stompClient!.activate();
      print('WebSocket connection activated');
      _reconnectAttempts = 0;
      _isReconnecting = false;
    } catch (e, stackTrace) {
      print('Error activating WebSocket connection:');
      print(e);
      print(stackTrace);
      _reconnectWebSocket();
      rethrow;
    }
  }

  void _reconnectWebSocket() async {
    if (_isReconnecting) return;
    _isReconnecting = true;

    print(
        'Attempting to reconnect WebSocket... (Attempt ${_reconnectAttempts + 1}/$maxReconnectAttempts)');

    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('Maximum reconnection attempts reached. Giving up.');
      _isReconnecting = false;
      return;
    }

    await Future.delayed(Duration(seconds: 5 * (_reconnectAttempts + 1)));

    if (!(_stompClient?.connected ?? false)) {
      try {
        _reconnectAttempts++;
        await connectToWebSocket();
      } catch (e) {
        print('Reconnection failed: $e');
        _isReconnecting = false;
      }
    }
  }

  void _onConnect(StompFrame frame) {
    print('Connected to WebSocket');
    print('Connection headers: ${frame.headers}');
    _reconnectAttempts = 0;
    _isReconnecting = false;

    // Подписываемся на обновления чатов
    _subscriptions['chats'] = _stompClient!.subscribe(
      destination: '/topic/chats',
      headers: {'Authorization': frame.headers['Authorization'] ?? ''},
      callback: (frame) {
        print('Received chat update: ${frame.body}');
        if (frame.body != null) {
          try {
            final chatJson = jsonDecode(frame.body!);
            final chat = Chat.fromJson(chatJson);
            _chatUpdateController.add(chat);
          } catch (e, stackTrace) {
            print('Ошибка обработки обновления чата:');
            print(e);
            print(stackTrace);
          }
        }
      },
    );
  }

  void _onDisconnect(StompFrame frame) {
    print('Disconnected from WebSocket');
    _subscriptions.clear();
  }

  void disconnectWebSocket() {
    _stompClient?.deactivate();
    _stompClient = null;
    _chatUpdateController.close();
  }

  Future<void> subscribeToChat(
    int chatId, {
    MessageCallback? onMessage,
    TypingCallback? onTyping,
    ReadCallback? onRead,
  }) async {
    if (!(_stompClient?.connected ?? false)) {
      print('WebSocket не подключен. Попытка подключения...');
      await connectToWebSocket();
    }

    final token = await _authProvider.getToken();
    if (token == null) {
      print('Ошибка: токен не найден');
      return;
    }

    final headers = <String, String>{
      'Authorization': 'Bearer $token',
    };

    try {
      print('Подписка на сообщения чата $chatId');

      // Инициализируем контроллер для чата, если его еще нет
      _messageControllers[chatId] ??=
          StreamController<List<ChatMessage>>.broadcast();

      // Загружаем начальные сообщения
      final initialMessages = await getChatMessages(chatId);
      _messageControllers[chatId]?.add(initialMessages);

      // Подписка на сообщения
      final messageKey = 'chat.$chatId';
      _subscriptions[messageKey] = _stompClient!.subscribe(
        destination: '/topic/chat.$chatId',
        headers: headers,
        callback: (frame) {
          print('Получено новое сообщение: ${frame.body}');
          if (frame.body != null) {
            try {
              final message = ChatMessage.fromJson(jsonDecode(frame.body!));
              print('Сообщение преобразовано: ${message.content}');

              // Получаем текущие сообщения
              getChatMessages(chatId).then((messages) {
                // Отправляем обновленный список в стрим
                _messageControllers[chatId]?.add(messages);
              });

              // Вызываем колбэк, если он предоставлен
              if (onMessage != null) {
                onMessage(message);
              }
            } catch (e, stackTrace) {
              print('Ошибка обработки сообщения:');
              print(e);
              print(stackTrace);
            }
          }
        },
      );

      // Подписка на уведомления о наборе текста
      final typingKey = 'chat.$chatId.typing';
      _subscriptions[typingKey] = _stompClient!.subscribe(
        destination: '/topic/chat.$chatId.typing',
        headers: headers,
        callback: (frame) {
          print('Получено уведомление о наборе текста');
          if (onTyping != null && frame.body != null) {
            try {
              final userId = int.parse(frame.body!);
              onTyping(userId);
            } catch (e) {
              print('Ошибка обработки уведомления о наборе: $e');
            }
          }
        },
      );

      // Подписка на уведомления о прочтении
      final readKey = 'chat.$chatId.read';
      _subscriptions[readKey] = _stompClient!.subscribe(
        destination: '/topic/chat.$chatId.read',
        headers: headers,
        callback: (frame) {
          print('Получено уведомление о прочтении');
          if (onRead != null && frame.body != null) {
            try {
              final userId = int.parse(frame.body!);
              onRead(userId);
            } catch (e) {
              print('Ошибка обработки уведомления о прочтении: $e');
            }
          }
        },
      );

      print('Успешно подписались на все события чата $chatId');
    } catch (e, stackTrace) {
      print('Ошибка при подписке на чат $chatId:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  void unsubscribeFromChat(int chatId) {
    final keys = [
      'chat.$chatId',
      'chat.$chatId.typing',
      'chat.$chatId.read',
    ];

    for (final key in keys) {
      if (_subscriptions.containsKey(key)) {
        _subscriptions[key]?.call();
        _subscriptions.remove(key);
      }
    }
  }

  Future<void> sendMessage(int chatId, String message, {int? replyToId}) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Отправка сообщения в чат $chatId:');
      print('- Текст: $message');
      print('- От пользователя: $userId');
      print('- В ответ на: $replyToId');

      // Отправляем через WebSocket
      if (_stompClient?.connected ?? false) {
        final messageData = {
          'chatId': chatId,
          'senderId': userId,
          'content': message,
          'replyToId': replyToId,
        };
        print('Отправляем данные: $messageData');

        _stompClient!.send(
          destination: '/app/chat.send',
          body: jsonEncode(messageData),
          headers: {'Authorization': 'Bearer $token'},
        );

        print('Сообщение успешно отправлено');
      } else {
        print('WebSocket не подключен');
        throw Exception('WebSocket не подключен');
      }
    } catch (e, stackTrace) {
      print('Ошибка при отправке сообщения:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  Future<void> markAsRead(int chatId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    if (_stompClient?.connected ?? false) {
      _stompClient!.send(
        destination: '/app/chat.read',
        body: jsonEncode({
          'chatId': chatId,
        }),
        headers: {'Authorization': 'Bearer $token'},
      );
    }
  }

  Future<void> notifyTyping(int chatId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    if (_stompClient?.connected ?? false) {
      _stompClient!.send(
        destination: '/app/chat.typing',
        body: jsonEncode({
          'chatId': chatId,
        }),
        headers: {'Authorization': 'Bearer $token'},
      );
    }
  }

  Stream<Chat> get chatUpdates => _chatUpdateController.stream;

  @override
  void dispose() {
    _chatUpdateController.close();
    // Закрываем все контроллеры сообщений
    for (var controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();
    disconnectWebSocket();
  }

  Future<List<ChatMessage>> getChatHistory(int chatId,
      {int limit = 50, int offset = 0}) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/chats/$chatId/messages?limit=$limit&offset=$offset'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> messagesJson = jsonDecode(response.body);
        return messagesJson.map((json) => ChatMessage.fromJson(json)).toList();
      } else {
        throw Exception(
            'Ошибка загрузки истории сообщений: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка при получении истории сообщений:');
      print(e);
      rethrow;
    }
  }

  Future<List<ChatMessage>> getUnreadMessages(int chatId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats/$chatId/messages/unread?userId=$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> messagesJson = jsonDecode(response.body);
        return messagesJson.map((json) => ChatMessage.fromJson(json)).toList();
      } else {
        throw Exception(
            'Ошибка загрузки непрочитанных сообщений: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка при получении непрочитанных сообщений:');
      print(e);
      rethrow;
    }
  }

  Future<List<ChatParticipant>> getChatParticipants(int chatId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats/$chatId/participants'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> participantsJson = jsonDecode(response.body);
        return participantsJson
            .map((json) => ChatParticipant.fromJson(json))
            .toList();
      } else {
        throw Exception(
            'Ошибка загрузки участников чата: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка при получении участников чата:');
      print(e);
      rethrow;
    }
  }

  Future<Chat> getChatByMeetupId(int meetupId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      print('Получаем чат для встречи $meetupId...');
      final response = await http.get(
        Uri.parse('$baseUrl/chats/meetup/$meetupId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final chatJson = jsonDecode(response.body);
        return Chat.fromJson(chatJson);
      } else if (response.statusCode == 404) {
        throw Exception('Чат для встречи не найден');
      } else {
        throw Exception('Ошибка получения чата: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Ошибка при получении чата для встречи:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  Future<List<ChatParticipantInfo>> getChatParticipantsInfo(int chatId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats/$chatId/participants/info'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> participantsJson = jsonDecode(response.body);
        return participantsJson
            .map((json) => ChatParticipantInfo.fromJson(json))
            .toList();
      } else {
        throw Exception(
            'Ошибка получения информации об участниках: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка при получении информации об участниках:');
      print(e);
      rethrow;
    }
  }

  Future<List<Chat>> getArchivedMeetups() async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Получаем архивные встречи...');
      final response = await http.get(
        Uri.parse('$baseUrl/meetups/archived'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка загрузки архивных встреч: ${response.statusCode}');
      }

      final List<dynamic> meetupsJson = jsonDecode(response.body);
      print('Получено архивных встреч: ${meetupsJson.length}');

      // Детальное логирование для отладки архивных встреч
      print('Содержимое архивных встреч (JSON):');
      for (var i = 0; i < meetupsJson.length; i++) {
        print('Архивная встреча #$i JSON: ${meetupsJson[i]}');

        // Логирование участников
        if (meetupsJson[i]['participants'] != null) {
          print('Участники архивной встречи #$i:');
          final participants = meetupsJson[i]['participants'] as List;
          for (var j = 0; j < participants.length; j++) {
            print('Участник #$j: ${participants[j]}');
            if (participants[j]['user'] != null) {
              print('- Пользователь: ${participants[j]['user']}');
              print('- ID: ${participants[j]['user']['userId']}');
              print('- Имя: ${participants[j]['user']['username']}');
              print('- Аватар: ${participants[j]['user']['avatarUrl']}');
            }
            print('- Статус: ${participants[j]['status']}');
          }
        } else {
          print('Участники архивной встречи #$i отсутствуют');
        }
      }

      final chats = meetupsJson.map((json) {
        // Преобразуем meetup в формат chat для совместимости
        final Map<String, dynamic> chatJson = {
          ...Map<String, dynamic>.from(json as Map),
          'chatId': json['meetupId'],
          // Принудительно устанавливаем lastMessageContent в null для архивных встреч
          'lastMessageContent': null,
        };
        return Chat.fromJson(chatJson);
      }).toList();

      // Проверяем, что все встречи имеют статус "completed"
      for (var chat in chats) {
        if (chat.meetupStatus != MeetupStatus.completed) {
          print(
              'Внимание: встреча ${chat.chatId} имеет статус ${chat.meetupStatus}, а не completed');
        }
      }

      print('Преобразовано архивных встреч: ${chats.length}');
      for (var chat in chats) {
        print('Архивная встреча: ${chat.name}');
        print('- ID чата: ${chat.chatId}');
        print('- ID встречи: ${chat.meetupId}');
        print('- Тип: ${chat.type}');
        print('- Время встречи: ${chat.scheduledTime}');
        print('- Статус: ${chat.meetupStatus}');
        print('- Организатор: ${chat.createdByName}');
        print('- Участники: ${chat.participants.length}');
        // Логирование участников после преобразования
        for (var i = 0; i < chat.participants.length; i++) {
          final participant = chat.participants[i];
          print(
              '- Участник #$i: ${participant.name} (ID: ${participant.userId})');
        }
      }

      return chats;
    } catch (e, stackTrace) {
      print('Ошибка при получении архивных встреч:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }
}
