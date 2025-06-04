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
  bool _isConnecting = false;
  Completer<void>? _connectionCompleter;

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

      // Выводим подробную информацию о полях в JSON
      for (var i = 0; i < meetupsJson.length; i++) {
        print('Встреча #$i JSON: ${meetupsJson[i]}');
        if (meetupsJson[i]['place'] != null) {
          print('Место встречи #$i: ${meetupsJson[i]['place']}');
        }
      }

      final chats = meetupsJson.map((json) {
        // Преобразуем meetup в формат chat для совместимости
        final Map<String, dynamic> chatJson = {
          ...Map<String, dynamic>.from(json as Map),
          'chatId': json['meetupId'],
        };

        // Явно обрабатываем scheduledTime, если он существует
        if (json['scheduledTime'] != null) {
          chatJson['scheduledTime'] = json['scheduledTime'];
        }

        // Обрабатываем информацию о месте
        if (json['place'] != null) {
          final place = json['place'] as Map<String, dynamic>;
          chatJson['placeName'] = place['name'];
          chatJson['placeAddress'] = place['address'];
          chatJson['latitude'] = place['latitude'];
          chatJson['longitude'] = place['longitude'];
          chatJson['placeImageUrl'] = place['imageUrl'];
        }

        return Chat.fromJson(chatJson);
      }).toList();

      print('Преобразовано активных встреч: ${chats.length}');
      for (var chat in chats) {
        print('Активная встреча: ${chat.name}');
        print('- ID чата: ${chat.chatId}');
        print('- ID встречи: ${chat.meetupId}');
        print('- Время встречи: ${chat.scheduledTime}');
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
      return []; // Возвращаем пустой список вместо исключения
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
    // Если уже подключено, просто возвращаемся
    if (_stompClient?.connected ?? false) {
      print('WebSocket уже подключен');
      return;
    }

    // Если подключение в процессе, ждем его завершения
    if (_isConnecting) {
      print('Подключение к WebSocket уже выполняется, ожидаем...');
      if (_connectionCompleter != null) {
        try {
          await _connectionCompleter!.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('Тайм-аут ожидания подключения WebSocket');
              _isConnecting = false;
              _connectionCompleter = null;
            },
          );
          // Если дождались, проверяем статус и возвращаемся если подключено
          if (_stompClient?.connected ?? false) {
            print('WebSocket подключен после ожидания');
            return;
          }
        } catch (e) {
          print('Ошибка при ожидании подключения: $e');
        }
      }
    }

    // Устанавливаем блокировку и создаем новый Completer
    _isConnecting = true;
    _connectionCompleter = Completer<void>();

    try {
      final token = await _authProvider.getToken();
      if (token == null) {
        throw Exception('Не авторизован');
      }

      // Проверяем еще раз после получения токена
      if (_stompClient?.connected ?? false) {
        print('WebSocket уже подключен (проверка после получения токена)');
        _connectionCompleter?.complete();
        return;
      }

      print('Connecting to WebSocket with token: $token');

      // Если есть существующий клиент, пытаемся деактивировать его
      if (_stompClient != null) {
        try {
          _stompClient!.deactivate();
          _stompClient = null;
          print('Существующий WebSocket клиент деактивирован');
        } catch (e) {
          print('Ошибка при деактивации WebSocket клиента: $e');
        }
      }

      _stompClient = StompClient(
        config: StompConfig(
          url: wsUrl,
          onConnect: (frame) {
            _onConnect(frame);
            // Завершаем комплитер, когда подключение успешно установлено
            if (!(_connectionCompleter?.isCompleted ?? true)) {
              _connectionCompleter?.complete();
            }
          },
          onDisconnect: (frame) {
            _onDisconnect(frame);
            // Если комплитер еще не завершен, завершаем его с ошибкой
            if (!(_connectionCompleter?.isCompleted ?? true)) {
              _connectionCompleter?.completeError('WebSocket отключен');
            }
          },
          onWebSocketError: (error) {
            print('WebSocket error: $error');
            // Если комплитер еще не завершен, завершаем его с ошибкой
            if (!(_connectionCompleter?.isCompleted ?? true)) {
              _connectionCompleter?.completeError(error);
            }
            _reconnectWebSocket();
          },
          onStompError: (error) {
            print('STOMP error: ${error.body}');
            // Если комплитер еще не завершен, завершаем его с ошибкой
            if (!(_connectionCompleter?.isCompleted ?? true)) {
              _connectionCompleter
                  ?.completeError('STOMP ошибка: ${error.body}');
            }
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

        // Ждем 2 секунды для установки соединения
        await Future.delayed(const Duration(seconds: 2));

        // Если комплитер еще не завершен и соединение не установлено,
        // завершаем его с ошибкой
        if (!(_connectionCompleter?.isCompleted ?? true) &&
            !(_stompClient?.connected ?? false)) {
          _connectionCompleter?.completeError('Тайм-аут подключения WebSocket');
        }
      } catch (e, stackTrace) {
        print('Error activating WebSocket connection:');
        print(e);
        print(stackTrace);

        // Если комплитер еще не завершен, завершаем его с ошибкой
        if (!(_connectionCompleter?.isCompleted ?? true)) {
          _connectionCompleter?.completeError(e);
        }

        _reconnectWebSocket();
        rethrow;
      }
    } catch (e) {
      print('Ошибка при подключении к WebSocket: $e');

      // Если комплитер еще не завершен, завершаем его с ошибкой
      if (!(_connectionCompleter?.isCompleted ?? true)) {
        _connectionCompleter?.completeError(e);
      }

      rethrow;
    } finally {
      // Снимаем блокировку после завершения
      _isConnecting = false;
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

    try {
      // Проверяем, не создана ли уже подписка на обновления чатов
      if (!_subscriptions.containsKey('chats')) {
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
    } catch (e) {
      print('Ошибка при подписке на обновления чатов: $e');
      // Не выбрасываем исключение, чтобы не прерывать работу приложения
    }
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

    // Проверяем, есть ли уже подписка на этот чат
    final messageKey = 'chat.$chatId';
    if (_subscriptions.containsKey(messageKey)) {
      print('Подписка на чат $chatId уже существует. Пропускаем.');
      return;
    }

    try {
      print('Подписка на сообщения чата $chatId');

      // Инициализируем контроллер для чата, если его еще нет
      _messageControllers[chatId] ??=
          StreamController<List<ChatMessage>>.broadcast();

      // Загружаем начальные сообщения
      final initialMessages = await getChatMessages(chatId);
      _messageControllers[chatId]?.add(initialMessages);

      // Подписка на сообщения
      _subscriptions[messageKey] = _stompClient!.subscribe(
        destination: '/topic/chat.$chatId',
        headers: headers,
        callback: (frame) {
          print('Получено новое сообщение: ${frame.body}');
          if (frame.body != null) {
            try {
              final message = ChatMessage.fromJson(jsonDecode(frame.body!));
              print('Сообщение преобразовано: ${message.content}');

              // Безопасно получаем текущие сообщения
              getChatMessages(chatId).then((messages) {
                try {
                  // Проверяем, что контроллер все еще существует и открыт
                  if (_messageControllers.containsKey(chatId) &&
                      !(_messageControllers[chatId]?.isClosed ?? true)) {
                    // Отправляем обновленный список в стрим
                    _messageControllers[chatId]?.add(messages);
                  }
                } catch (e) {
                  print('Ошибка при обновлении сообщений в стриме: $e');
                }
              }).catchError((e) {
                print('Ошибка при получении обновленных сообщений: $e');
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
      // Не выбрасываем исключение, чтобы не прерывать выполнение
      // просто логируем ошибку
    }
  }

  void unsubscribeFromChat(int chatId) {
    final keys = [
      'chat.$chatId',
      'chat.$chatId.typing',
      'chat.$chatId.read',
    ];

    try {
      for (final key in keys) {
        if (_subscriptions.containsKey(key)) {
          try {
            // Безопасно вызываем функцию отписки
            _subscriptions[key]?.call();
          } catch (e) {
            print('Ошибка при отписке от $key: $e');
          } finally {
            // В любом случае удаляем ключ из словаря подписок
            _subscriptions.remove(key);
          }
        }
      }

      // Проверяем, существует ли контроллер сообщений для этого чата
      if (_messageControllers.containsKey(chatId)) {
        // Не закрываем контроллер, так как он может использоваться другими экземплярами страницы
        // Просто удаляем ссылку на него из словаря
        print('Удаляем контроллер сообщений для чата $chatId из словаря');
        _messageControllers.remove(chatId);
      }
    } catch (e) {
      print('Ошибка при отписке от чата $chatId: $e');
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
    // Безопасно закрываем контроллер обновлений чата
    if (!_chatUpdateController.isClosed) {
      _chatUpdateController.close();
    }

    // Безопасно закрываем все контроллеры сообщений
    for (var chatId in _messageControllers.keys) {
      try {
        if (!(_messageControllers[chatId]?.isClosed ?? true)) {
          _messageControllers[chatId]?.close();
        }
      } catch (e) {
        print('Ошибка при закрытии контроллера сообщений для чата $chatId: $e');
      }
    }
    _messageControllers.clear();

    // Отключаемся от WebSocket
    try {
      disconnectWebSocket();
    } catch (e) {
      print('Ошибка при отключении от WebSocket: $e');
    }
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

        // Логируем содержимое JSON для отладки
        print('JSON для чата $meetupId: $chatJson');
        if (chatJson['meetup'] != null &&
            chatJson['meetup']['scheduledTime'] != null) {
          print(
              'Найдено вложенное время встречи: ${chatJson['meetup']['scheduledTime']}');
        }

        // Обрабатываем информацию о месте
        if (chatJson['place'] != null) {
          final place = chatJson['place'] as Map<String, dynamic>;
          chatJson['placeName'] = place['name'];
          chatJson['placeAddress'] = place['address'];
          chatJson['latitude'] = place['latitude'];
          chatJson['longitude'] = place['longitude'];
          chatJson['placeImageUrl'] = place['imageUrl'];
        } else if (chatJson['meetup'] != null &&
            chatJson['meetup']['place'] != null) {
          final place = chatJson['meetup']['place'] as Map<String, dynamic>;
          chatJson['placeName'] = place['name'];
          chatJson['placeAddress'] = place['address'];
          chatJson['latitude'] = place['latitude'];
          chatJson['longitude'] = place['longitude'];
          chatJson['placeImageUrl'] = place['imageUrl'];
        }

        final chat = Chat.fromJson(chatJson);
        print('Созданный объект Chat для $meetupId:');
        print('- scheduledTime: ${chat.scheduledTime}');
        print('- name: ${chat.name}');
        print('- lastMessageContent: ${chat.lastMessageContent}');
        print('- placeName: ${chat.placeName}');
        print('- placeAddress: ${chat.placeAddress}');

        return chat;
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

        // Обрабатываем информацию о месте
        print('Обработка данных о месте для встречи ${json['meetupId']}:');
        print('- Наличие поля place: ${json['place'] != null}');
        print(
            '- Наличие поля meetup.place: ${json['meetup']?['place'] != null}');

        if (json['place'] != null) {
          final place = json['place'] as Map<String, dynamic>;
          print('- Найдено место в корне JSON:');
          print('  - name: ${place['name']}');
          print('  - address: ${place['address']}');
          print('  - latitude: ${place['latitude']}');
          print('  - longitude: ${place['longitude']}');
          print('  - imageUrl: ${place['imageUrl']}');

          chatJson['placeName'] = place['name'];
          chatJson['placeAddress'] = place['address'];
          chatJson['latitude'] = place['latitude'];
          chatJson['longitude'] = place['longitude'];
          chatJson['placeImageUrl'] = place['imageUrl'];
        } else if (json['meetup'] != null && json['meetup']['place'] != null) {
          final place = json['meetup']['place'] as Map<String, dynamic>;
          print('- Найдено место в объекте meetup:');
          print('  - name: ${place['name']}');
          print('  - address: ${place['address']}');
          print('  - latitude: ${place['latitude']}');
          print('  - longitude: ${place['longitude']}');
          print('  - imageUrl: ${place['imageUrl']}');

          chatJson['placeName'] = place['name'];
          chatJson['placeAddress'] = place['address'];
          chatJson['latitude'] = place['latitude'];
          chatJson['longitude'] = place['longitude'];
          chatJson['placeImageUrl'] = place['imageUrl'];
        } else {
          print('- Данные о месте не найдены');
        }

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
