import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:http/http.dart' as http;
import '../models/chat.dart';
import '../models/chat_message.dart';
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

  ChatService(this._authProvider);

  // REST API методы

  Future<List<Chat>> getUserChats() async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Получаем чаты пользователя...');
      // Получаем все чаты пользователя
      final chatsResponse = await http.get(
        Uri.parse('$baseUrl/chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (chatsResponse.statusCode != 200) {
        throw Exception('Ошибка загрузки чатов: ${chatsResponse.statusCode}');
      }

      final List<dynamic> chatsJson = jsonDecode(chatsResponse.body);
      print('Получено чатов: ${chatsJson.length}');

      print('Получаем встречи пользователя...');
      // Получаем встречи через новый эндпоинт
      final meetupsResponse = await http.get(
        Uri.parse('$baseUrl/meetups/owned-and-accepted/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (meetupsResponse.statusCode != 200) {
        throw Exception(
            'Ошибка загрузки встреч: ${meetupsResponse.statusCode}');
      }

      final List<dynamic> meetupsJson = jsonDecode(meetupsResponse.body);
      print('Получено встреч: ${meetupsJson.length}');

      // Преобразуем встречи в чаты
      final meetupChats = await _convertMeetupsToChats(meetupsJson);

      // Объединяем все чаты
      final allChats = [
        ...chatsJson.map((json) => Chat.fromJson(json)),
        ...meetupChats
      ];

      // Удаляем дубликаты по chatId
      final uniqueChats = allChats
          .fold<Map<int, Chat>>({}, (map, chat) {
            map[chat.chatId] = chat;
            return map;
          })
          .values
          .toList();

      print('Всего уникальных чатов: ${uniqueChats.length}');
      return uniqueChats;
    } catch (e, stackTrace) {
      print('Ошибка при получении чатов:');
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

    final response = await http.get(
      Uri.parse('$baseUrl/chats/$chatId/messages?limit=$limit&offset=$offset'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('Ответ сервера: ${response.statusCode}');
    print('Тело ответа: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> messagesJson = jsonDecode(response.body);
      return messagesJson.map((json) => ChatMessage.fromJson(json)).toList();
    } else {
      throw Exception(
          'Ошибка загрузки сообщений: ${response.statusCode} - ${response.body}');
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

  Future<void> acceptMeetupInvitation(int meetupId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Принимаем приглашение на встречу $meetupId...');
      final response = await http.put(
        Uri.parse(
            '$baseUrl/meetups/$meetupId/participants/$userId?status=accepted'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('Приглашение успешно принято');
        // Уведомляем подписчиков об обновлении чата
        final updatedMeetup = jsonDecode(response.body);
        final participants = updatedMeetup['participants'] as List<dynamic>;
        _chatUpdateController.add(Chat.fromJson({
          'chatId': updatedMeetup['meetupId'],
          'name': updatedMeetup['name'],
          'type': 'meetup',
          'createdById': updatedMeetup['creator']['userId'],
          'createdByName': updatedMeetup['creator']['username'],
          'createdByAvatar': updatedMeetup['creator']['avatarUrl'],
          'createdAt': updatedMeetup['createdAt'],
          'isGroup': true,
          'meetupId': updatedMeetup['meetupId'],
          'scheduledTime': updatedMeetup['scheduledTime'],
          'meetupStatus': updatedMeetup['status'],
          'unreadCount': 0,
          'participants': participants.map((p) {
            final user = p['user'] as Map<String, dynamic>;
            return {
              'participantId': p['participantId'],
              'chatId': updatedMeetup['meetupId'],
              'userId': user['userId'],
              'userName': user['username'],
              'userAvatar': user['avatarUrl'],
              'joinedAt': p['invitedAt'],
              'leftAt': null,
              'role': 'member'
            };
          }).toList(),
          'currentUserStatus': 'accepted'
        }));
      } else {
        print('Ошибка при принятии приглашения: ${response.statusCode}');
        print('Ответ сервера: ${response.body}');
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

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Отклоняем приглашение на встречу $meetupId...');
      final response = await http.put(
        Uri.parse(
            '$baseUrl/meetups/$meetupId/participants/$userId?status=declined'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('Приглашение успешно отклонено');
        // Уведомляем подписчиков об обновлении чата
        final updatedMeetup = jsonDecode(response.body);
        final participants = updatedMeetup['participants'] as List<dynamic>;
        _chatUpdateController.add(Chat.fromJson({
          'chatId': updatedMeetup['meetupId'],
          'name': updatedMeetup['name'],
          'type': 'meetup',
          'createdById': updatedMeetup['creator']['userId'],
          'createdByName': updatedMeetup['creator']['username'],
          'createdByAvatar': updatedMeetup['creator']['avatarUrl'],
          'createdAt': updatedMeetup['createdAt'],
          'isGroup': true,
          'meetupId': updatedMeetup['meetupId'],
          'scheduledTime': updatedMeetup['scheduledTime'],
          'meetupStatus': updatedMeetup['status'],
          'unreadCount': 0,
          'participants': participants.map((p) {
            final user = p['user'] as Map<String, dynamic>;
            return {
              'participantId': p['participantId'],
              'chatId': updatedMeetup['meetupId'],
              'userId': user['userId'],
              'userName': user['username'],
              'userAvatar': user['avatarUrl'],
              'joinedAt': p['invitedAt'],
              'leftAt': null,
              'role': 'member'
            };
          }).toList(),
          'currentUserStatus': 'declined'
        }));
      } else {
        print('Ошибка при отклонении приглашения: ${response.statusCode}');
        print('Ответ сервера: ${response.body}');
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

  Future<List<Chat>> getInvitedMeetups() async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Получаем приглашения на встречи...');
      final response = await http.get(
        Uri.parse('$baseUrl/meetups/invitations/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> meetupsJson = jsonDecode(response.body);
        print('Получено приглашений: ${meetupsJson.length}');

        // Преобразуем встречи в формат чатов
        final List<Map<String, dynamic>> meetupChats =
            meetupsJson.map((meetup) {
          final creator = meetup['creator'] as Map<String, dynamic>;
          final place = meetup['place'] as Map<String, dynamic>;
          final participants = meetup['participants'] as List<dynamic>;

          // Находим статус текущего пользователя
          final currentUserParticipant = participants.firstWhere(
            (p) => (p['user'] as Map<String, dynamic>)['userId'] == userId,
            orElse: () => null,
          );

          print('Преобразование приглашения: ${meetup['name']}');
          print('- ID встречи: ${meetup['meetupId']}');
          print('- Создатель: ${creator['username']}');
          print('- Место: ${place['name']}');
          print('- Статус: ${meetup['status']}');
          print('- Участников: ${participants.length}');

          return {
            'chatId': meetup['meetupId'],
            'name': meetup['name'],
            'createdById': creator['userId'],
            'createdByName': creator['username'],
            'createdByAvatar': creator['avatarUrl'],
            'createdAt': meetup['createdAt'],
            'isGroup': true,
            'meetupId': meetup['meetupId'],
            'scheduledTime': meetup['scheduledTime'],
            'meetupStatus': meetup['status'],
            'unreadCount': 0,
            'participants': participants.map((p) {
              final user = p['user'] as Map<String, dynamic>;
              return {
                'participantId': p['participantId'],
                'chatId': meetup['meetupId'],
                'userId': user['userId'],
                'userName': user['username'],
                'userAvatar': user['avatarUrl'],
                'joinedAt': p['invitedAt'],
                'leftAt': null,
                'role': 'member'
              };
            }).toList(),
            'currentUserStatus': currentUserParticipant?['status'] ?? 'invited'
          };
        }).toList();

        print('Преобразовано встреч: ${meetupChats.length}');
        return meetupChats.map((json) => Chat.fromJson(json)).toList();
      } else {
        print('Ошибка загрузки приглашений: ${response.statusCode}');
        print('Ответ сервера: ${response.body}');
        throw Exception('Ошибка загрузки приглашений: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Ошибка при получении приглашений:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  Future<List<Chat>> getActiveMeetups() async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Получаем активные встречи...');
      final response = await http.get(
        Uri.parse('$baseUrl/meetups/active/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> meetupsJson = jsonDecode(response.body);
        return await _convertMeetupsToChats(meetupsJson);
      } else {
        print('Ошибка загрузки активных встреч: ${response.statusCode}');
        print('Ответ сервера: ${response.body}');
        throw Exception(
            'Ошибка загрузки активных встреч: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Ошибка при получении активных встреч:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  Future<List<Chat>> getPendingMeetups() async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Получаем ожидающие встречи...');
      final response = await http.get(
        Uri.parse('$baseUrl/meetups/pending/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> meetupsJson = jsonDecode(response.body);
        return await _convertMeetupsToChats(meetupsJson);
      } else {
        print('Ошибка загрузки ожидающих встреч: ${response.statusCode}');
        print('Ответ сервера: ${response.body}');
        throw Exception(
            'Ошибка загрузки ожидающих встреч: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Ошибка при получении ожидающих встреч:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  Future<List<Chat>> getOwnedAndAcceptedMeetups() async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    try {
      print('Получаем созданные и принятые встречи...');
      final response = await http.get(
        Uri.parse('$baseUrl/meetups/owned-and-accepted/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> meetupsJson = jsonDecode(response.body);
        return await _convertMeetupsToChats(meetupsJson);
      } else {
        print(
            'Ошибка загрузки созданных и принятых встреч: ${response.statusCode}');
        print('Ответ сервера: ${response.body}');
        throw Exception(
            'Ошибка загрузки созданных и принятых встреч: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Ошибка при получении созданных и принятых встреч:');
      print(e);
      print(stackTrace);
      rethrow;
    }
  }

  Future<List<Chat>> _convertMeetupsToChats(List<dynamic> meetupsJson) async {
    final userId = await _authProvider.getUserId();
    if (userId == null) throw Exception('Не авторизован');

    final List<Chat> meetupChats = [];

    for (var meetup in meetupsJson) {
      try {
        final creator = meetup['creator'] as Map<String, dynamic>;
        final participants = meetup['participants'] as List<dynamic>;

        print('Преобразование встречи в чат:');
        print('- ID встречи: ${meetup['meetupId']}');
        print('- Название: ${meetup['name']}');
        print('- Статус встречи: ${meetup['status']}');

        // Находим статус текущего пользователя
        String currentUserStatus;
        if (creator['userId'] == userId) {
          currentUserStatus = 'accepted';
        } else {
          final userParticipant = participants.firstWhere(
            (p) => (p['user'] as Map<String, dynamic>)['userId'] == userId,
            orElse: () => null,
          );
          currentUserStatus = userParticipant?['status'] ?? 'invited';
        }

        print('- Статус текущего пользователя: $currentUserStatus');

        final chatJson = {
          'chatId': meetup['meetupId'],
          'name': meetup['name'],
          'type': 'meetup',
          'createdById': creator['userId'],
          'createdByName': creator['username'],
          'createdByAvatar': creator['avatarUrl'],
          'createdAt': meetup['createdAt'],
          'isGroup': true,
          'meetupId': meetup['meetupId'],
          'scheduledTime': meetup['scheduledTime'],
          'meetupStatus': meetup['status'],
          'currentUserStatus': currentUserStatus,
          'participants': participants.map((p) {
            final user = p['user'] as Map<String, dynamic>;
            return {
              'userId': user['userId'],
              'userName': user['username'],
              'userAvatar': user['avatarUrl'],
              'role': 'member',
              'joinedAt': p['invitedAt'],
              'leftAt': null
            };
          }).toList(),
        };

        final chat = Chat.fromJson(chatJson);
        print('Создан чат:');
        print('- ID: ${chat.chatId}');
        print('- Тип: ${chat.type}');
        print('- Статус встречи: ${chat.meetupStatus}');
        print('- Статус пользователя: ${chat.currentUserStatus}');
        print('- Активен: ${chat.isActive}');

        meetupChats.add(chat);
      } catch (e, stackTrace) {
        print('Ошибка при преобразовании встречи ${meetup['meetupId']}:');
        print(e);
        print(stackTrace);
      }
    }

    return meetupChats;
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
        onWebSocketError: (error) => print('WebSocket error: $error'),
        onStompError: (error) => print('STOMP error: ${error.body}'),
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
    } catch (e) {
      print('Error activating WebSocket connection: $e');
      rethrow;
    }
  }

  void _onConnect(StompFrame frame) {
    print('Connected to WebSocket');
    print('Connection headers: ${frame.headers}');

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
          } catch (e) {
            print('Ошибка обработки обновления чата: $e');
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
    if (!(_stompClient?.connected ?? false)) return;

    final token = await _authProvider.getToken();
    if (token == null) return;

    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // Подписка на сообщения
    final messageKey = 'chat.$chatId';
    _subscriptions[messageKey] = _stompClient!.subscribe(
      destination: '/topic/chat.$chatId',
      headers: headers,
      callback: (frame) {
        if (onMessage != null && frame.body != null) {
          try {
            final message = ChatMessage.fromJson(jsonDecode(frame.body!));
            onMessage(message);
          } catch (e) {
            print('Ошибка обработки сообщения: $e');
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
        if (onTyping != null && frame.body != null) {
          try {
            final data = jsonDecode(frame.body!);
            if (data['userId'] is int) {
              onTyping(data['userId']);
            }
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
        if (onRead != null && frame.body != null) {
          try {
            final data = jsonDecode(frame.body!);
            if (data['userId'] is int) {
              onRead(data['userId']);
            }
          } catch (e) {
            print('Ошибка обработки уведомления о прочтении: $e');
          }
        }
      },
    );
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
      final response = await http.post(
        Uri.parse('$baseUrl/chats/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'chatId': chatId,
          'senderId': userId,
          'content': message,
          'replyToId': replyToId,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Ошибка отправки сообщения: ${response.statusCode}');
      }

      // Отправляем через WebSocket, если подключен
      if (_stompClient?.connected ?? false) {
        _stompClient!.send(
          destination: '/app/chat.send',
          body: jsonEncode({
            'chatId': chatId,
            'content': message,
            'replyToId': replyToId,
          }),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } catch (e) {
      print('Ошибка при отправке сообщения:');
      print(e);
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
}
